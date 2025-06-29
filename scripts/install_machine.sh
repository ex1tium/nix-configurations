#!/usr/bin/env -S bash -Eeuo pipefail
# ──────────────────────────────────────────────────────────────────────────────
#  « install_machine.sh » – Generic NixOS installer (Btrfs / ext4 only)
#      • Fresh / Dual-boot / Manual modes
#      • Optional LUKS2 encryption
#      • Snapper-ready layout if Btrfs
#      • Re-uses lib/common.sh for *all* heavy lifting
# ──────────────────────────────────────────────────────────────────────────────

shopt -s inherit_errexit lastpipe
IFS=$'\n\t'

###############################################################################
# 0.  Shared helpers
###############################################################################
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOG_FILE="/tmp/nixos-install-$(date +%Y%m%d-%H%M%S).log"; export LOG_FILE
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

###############################################################################
# 1.  Globals / defaults
###############################################################################
readonly SCRIPT_VERSION="3.0.0"
readonly REPO_URL_DEFAULT="https://github.com/ex1tium/nix-configurations.git"

# Dynamic step counter to avoid drift
CURRENT_STEP=0
TOTAL_STEPS=0

# Calculate total steps dynamically based on execution path
calculate_total_steps() {
  # Fixed total steps for now - can be made dynamic later if needed
  TOTAL_STEPS=14
  export TOTAL_STEPS
}

# Dynamic step printer
next_step() {
  local description=$1
  CURRENT_STEP=$((CURRENT_STEP + 1))
  print_step "$CURRENT_STEP" "$TOTAL_STEPS" "$description"
}

REPO_URL=$REPO_URL_DEFAULT
REPO_BRANCH="main"

INSTALLATION_MODE=""               # fresh | dual-boot | manual
SELECTED_FILESYSTEM="btrfs"        # btrfs | ext4
ENABLE_SNAPSHOTS=1
ENABLE_ENCRYPTION=""               # "",1,0

SELECTED_MACHINE=""
SELECTED_DISK=""
ESP_PARTITION=""
ROOT_PARTITION=""
HOME_PARTITION=""

PRIMARY_USER=""
LUKS_PASSPHRASE_FILE=""

DRY_RUN=0 NON_INTERACTIVE=0 QUIET=0 DEBUG=0 FORCE_YES=0
readonly ORIGINAL_ARGS=("$@")
readonly NIX_FLAGS="$(get_nix_flags)"

###############################################################################
# 2.  CLI parsing
###############################################################################
usage() {
  cat <<EOF
Usage: $0 [options]

Core:
  -m, --machine    <name>            Machine output from flake
  -d, --disk       <device>          Target disk (/dev/sdX, /dev/nvme0n1 …)
  -f, --filesystem <btrfs|ext4>      Target filesystem (default: btrfs)
  -e, --encrypt                      Enable LUKS2 encryption
  -E, --no-encrypt                   Disable encryption
      --luks-pass  <file>            LUKS passphrase file (required for non-interactive encryption)
      --mode       <fresh|dual-boot|manual>  Installation mode (default: fresh)
  -u, --user       <name>            UNIX user (auto-detected otherwise)
  -r, --repo       <url>             Config repo (default: $REPO_URL_DEFAULT)
  -b, --branch     <branch>          Git branch (default: main)

Behaviour:
      --dry-run                      Show actions, do nothing destructive
      --non-interactive              Require mandatory flags, no prompts
      --yes                          Assume YES on confirmations
      --quiet | --debug
      --log-path   <file>            Custom logfile
      --no-color

  -h, --help       Show this help
  -v, --version    Print version
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -m|--machine)     SELECTED_MACHINE=$2; shift 2 ;;
      -d|--disk)        SELECTED_DISK=$2; shift 2 ;;
      -f|--filesystem)  SELECTED_FILESYSTEM=$2; shift 2 ;;
      -e|--encrypt)     ENABLE_ENCRYPTION=1; shift ;;
      -E|--no-encrypt)  ENABLE_ENCRYPTION=0; shift ;;
      --luks-pass)      LUKS_PASSPHRASE_FILE=$2; shift 2 ;;
      --mode)           INSTALLATION_MODE=$2; shift 2 ;;
      -u|--user)        PRIMARY_USER=$2; shift 2 ;;
      -r|--repo)        REPO_URL=$2; shift 2 ;;
      -b|--branch)      REPO_BRANCH=$2; shift 2 ;;
      --dry-run)        DRY_RUN=1; shift ;;
      --non-interactive)NON_INTERACTIVE=1; shift ;;
      --yes)            FORCE_YES=1; shift ;;
      --quiet)          QUIET=1; shift ;;
      --debug)          DEBUG=1; shift ;;
      --no-color)       NO_COLOR=1; shift ;;
      --log-path)       LOG_FILE=$2; export LOG_FILE; shift 2 ;;
      -h|--help)        usage; exit 0 ;;
      -v|--version)     echo "$SCRIPT_VERSION"; exit 0 ;;
      --) shift; break ;;
      *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  # Sanity
  [[ $SELECTED_FILESYSTEM =~ ^(btrfs|ext4)$ ]] ||
      { echo "Unsupported filesystem: $SELECTED_FILESYSTEM"; exit 1; }

  [[ $SELECTED_FILESYSTEM == btrfs ]] || ENABLE_SNAPSHOTS=0

  if [[ -n $INSTALLATION_MODE ]] &&
     ! [[ $INSTALLATION_MODE =~ ^(fresh|dual-boot|manual)$ ]]; then
      echo "Invalid --mode: $INSTALLATION_MODE"; exit 1;
  fi

  if (( NON_INTERACTIVE )); then
      local miss=()
      [[ -z $SELECTED_MACHINE    ]] && miss+=(--machine)
      [[ -z $SELECTED_DISK       ]] && miss+=(--disk)
      [[ -z $ENABLE_ENCRYPTION   ]] && miss+=(--encrypt/--no-encrypt)
      [[ -z $INSTALLATION_MODE   ]] && miss+=(--mode)

      # Check for encryption passphrase file if encryption is enabled
      if [[ $ENABLE_ENCRYPTION == "1" && -z $LUKS_PASSPHRASE_FILE ]]; then
          miss+=(--luks-pass)
      fi

      (( ${#miss[@]} )) && { echo "Missing flags in non-interactive mode: ${miss[*]}"; exit 1; }
  fi

  # Validate passphrase file if provided
  if [[ -n $LUKS_PASSPHRASE_FILE && ! -f $LUKS_PASSPHRASE_FILE ]]; then
      echo "LUKS passphrase file not found: $LUKS_PASSPHRASE_FILE"; exit 1
  fi

  export DRY_RUN NON_INTERACTIVE QUIET DEBUG
}

###############################################################################
# 3.  Error handling / cleanup
###############################################################################
cleanup_and_exit() {
  local code=${1:-0}
  if [[ ${USER_OVERRIDE:-} && -f $USER_OVERRIDE && $code -eq 0 && $DRY_RUN -eq 0 ]]; then
    rm -f "$USER_OVERRIDE"
  fi
  safe_unmount /mnt
  cleanup_temp_files
  (( QUIET )) || echo -e "${GREEN}Done – log:${NC} $LOG_FILE"
  exit "$code"
}
trap 'log_error "Error on line $LINENO (exit $?)"; cleanup_and_exit 1' ERR
trap 'cleanup_and_exit 130' INT TERM

###############################################################################
# 4.  Validation & dependency bootstrap
###############################################################################
validate_system() {
  next_step "System validation"
  validate_installation_environment
}

bootstrap_dependencies() {
  next_step "Dependency bootstrap"
  local pkgs=(git parted util-linux gptfdisk cryptsetup rsync tar jq bc)

  if ! bootstrap_nix_dependencies "${pkgs[@]}"; then
    (( $? == 2 )) && exec nix-shell -p "${pkgs[@]}" --run "bash \"$0\" ${ORIGINAL_ARGS[*]}"
    log_error "Dependency check failed. Exiting."
    cleanup_and_exit 1
  fi
}

###############################################################################
# 5.  Repository & machine discovery
###############################################################################
setup_repository() {
  next_step "Clone configuration repository"
  setup_config_repository "$REPO_URL" "$REPO_BRANCH" /tmp/nix-config
  cd /tmp/nix-config
}

discover_machines() {
  next_step "Discover machine configurations"
  mapfile -t DISCOVERED_MACHINES < <(discover_machine_configs machines)
}

###############################################################################
# 6.  Interactive selections
###############################################################################
select_installation_mode() {
  next_step "Select installation mode"
  [[ -n $INSTALLATION_MODE ]] && return
  (( NON_INTERACTIVE )) && { log_error "Mode required"; exit 1; }

  echo "  [1] Fresh  (erase whole disk)"
  echo "  [2] Dual-boot (reuse free space)"
  echo "  [3] Manual (you partition yourself)"
  read -rp "Choose mode [1-3]: " ans
  case $ans in
     1) INSTALLATION_MODE="fresh" ;;
     2) INSTALLATION_MODE="dual-boot" ;;
     3) INSTALLATION_MODE="manual" ;;
     *) echo "Invalid choice"; exit 1 ;;
  esac
}

select_machine() {
  next_step "Select machine"
  [[ -n $SELECTED_MACHINE ]] && return
  (( NON_INTERACTIVE )) && { log_error "Machine required"; exit 1; }
  for i in "${!DISCOVERED_MACHINES[@]}"; do
      printf "  [%d] %s\n" $((i+1)) "${DISCOVERED_MACHINES[$i]}"
  done
  read -rp "Machine: " n
  SELECTED_MACHINE=${DISCOVERED_MACHINES[$((n-1))]}
}

select_filesystem() {
  next_step "Select filesystem"
  if (( NON_INTERACTIVE )); then
    ENABLE_SNAPSHOTS=$([[ $SELECTED_FILESYSTEM == btrfs ]] && echo 1 || echo 0)
    return
  fi
  echo "  [1] Btrfs (snapshots)  [2] ext4"
  read -rp "FS: " choice
  case $choice in
    2) SELECTED_FILESYSTEM="ext4"; ENABLE_SNAPSHOTS=0 ;;   # ext4
    *) SELECTED_FILESYSTEM="btrfs"; ENABLE_SNAPSHOTS=1 ;;  # default = btrfs
  esac
}

select_encryption() {
  next_step "Encryption"
  [[ -n $ENABLE_ENCRYPTION ]] && return
  (( NON_INTERACTIVE )) && { log_error "Encryption flag required"; exit 1; }

  read -rp "Enable LUKS2? [y/N]: " a
  ENABLE_ENCRYPTION=$([[ ${a,,} == y* ]] && echo 1 || echo 0)
}

select_disk() {
  next_step "Disk selection"
  [[ -n $SELECTED_DISK ]] && return
  (( NON_INTERACTIVE )) && { log_error "Disk required"; exit 1; }

  mapfile -t disks < <(list_disks)
  for i in "${!disks[@]}"; do
     sz=$(lsblk -bno SIZE "${disks[$i]}" 2>/dev/null | head -1)
     sz=${sz:-0}  # lsblk -bno already gives pure numbers, just handle empty case
     printf "  [%d] %s  %dGiB\n" $((i+1)) "${disks[$i]}" $((sz/1024/1024/1024))
  done
  read -rp "Disk: " n
  SELECTED_DISK=${disks[$((n-1))]}

  case $INSTALLATION_MODE in
    fresh)
      confirm_action "Erase ALL data on $SELECTED_DISK ?" || exit 1 ;;
    dual-boot)
      confirm_action "Use free space on $SELECTED_DISK ?"   || exit 1 ;;
    manual)
      echo "Manual mode – you partition yourself." ;;
  esac
}

###############################################################################
# 7.  Environment cleanup operations
###############################################################################
cleanup_previous_installation() {
  next_step "Clean up previous installation attempts"

  if is_dry_run; then
    log_info "DRY-RUN: Would perform comprehensive cleanup"
    return 0
  fi

  # Check if cleanup is needed
  local cleanup_needed=false

  # Check for existing mounts
  if mount | grep -q ' /mnt'; then
    cleanup_needed=true
    log_info "Found existing mount points under /mnt"
  fi

  # Check for existing partitions on target disk
  if lsblk -ln -o NAME "$SELECTED_DISK" | grep -q "$(basename "$SELECTED_DISK")[0-9]"; then
    cleanup_needed=true
    log_info "Found existing partitions on $SELECTED_DISK"
  fi

  # Check for BTRFS subvolumes
  local root_partition="${SELECTED_DISK}2"
  if [[ -b $root_partition ]] && blkid -t TYPE=btrfs "$root_partition" &>/dev/null; then
    cleanup_needed=true
    log_info "Found existing BTRFS filesystem on $root_partition"
  fi

  if ! $cleanup_needed; then
    log_info "No cleanup needed - disk appears clean"
    return 0
  fi

  # Prompt for confirmation unless non-interactive
  if (( ! NON_INTERACTIVE )); then
    echo
    log_warn "CLEANUP REQUIRED: Previous installation artifacts detected"
    echo "  This will:"
    echo "  - Unmount all mount points under /mnt"
    echo "  - Delete any existing BTRFS subvolumes on $SELECTED_DISK"
    echo "  - Wipe filesystem signatures from existing partitions"
    echo "  - Clean up temporary files"
    echo
    read -rp "Proceed with cleanup? [y/N]: " confirm
    case $confirm in
      [Yy]|[Yy][Ee][Ss]) ;;
      *) log_error "Cleanup cancelled by user"; exit 1 ;;
    esac
  fi

  log_info "Starting comprehensive environment cleanup..."

  # 1. Unmount all existing mount points under /mnt
  cleanup_mount_points

  # 2. Clean up BTRFS subvolumes if they exist
  cleanup_btrfs_subvolumes

  # 3. Wipe filesystem signatures from target partitions
  cleanup_filesystem_signatures

  # 4. Reset temporary files and state
  cleanup_temporary_files

  # 5. Validate clean state
  validate_clean_disk_state

  log_info "Environment cleanup completed successfully"
}

cleanup_mount_points() {
  log_info "Unmounting all mount points under /mnt..."

  # Get all mount points under /mnt in reverse order (deepest first)
  local mounts
  mounts=$(mount | grep ' /mnt' | awk '{print $3}' | sort -r)

  if [[ -n $mounts ]]; then
    while IFS= read -r mount_point; do
      log_info "Unmounting: $mount_point"
      if ! umount "$mount_point" 2>/dev/null; then
        log_warn "Failed to unmount $mount_point, trying force unmount..."
        umount -f "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null
      fi
    done <<< "$mounts"
  else
    log_info "No mount points under /mnt found"
  fi

  # Ensure /mnt itself is unmounted
  if mountpoint -q /mnt 2>/dev/null; then
    log_info "Unmounting /mnt"
    umount /mnt 2>/dev/null || umount -f /mnt 2>/dev/null || umount -l /mnt 2>/dev/null
  fi
}

cleanup_btrfs_subvolumes() {
  log_info "Cleaning up existing BTRFS subvolumes on $SELECTED_DISK..."

  # Use proper root partition detection instead of hardcoded ${disk}2
  local root_partition
  if [[ -n $ROOT_PARTITION ]]; then
    root_partition="$ROOT_PARTITION"
  else
    # Fallback: try to determine root partition based on installation mode
    root_partition=$(get_root_partition "$SELECTED_DISK" "${INSTALLATION_MODE:-fresh}")
  fi

  # Check if partition exists and has BTRFS filesystem
  if [[ ! -b $root_partition ]]; then
    log_info "Root partition $root_partition does not exist, skipping BTRFS cleanup"
    return 0
  fi

  # Check if it's a BTRFS filesystem
  if ! blkid -t TYPE=btrfs "$root_partition" &>/dev/null; then
    log_info "No BTRFS filesystem found on $root_partition"
    return 0
  fi

  log_info "Found BTRFS filesystem on $root_partition, cleaning up subvolumes..."

  # Create temporary mount point for cleanup
  local temp_mount="/tmp/btrfs_cleanup_$$"
  mkdir -p "$temp_mount"

  # Mount the BTRFS filesystem
  if mount "$root_partition" "$temp_mount" 2>/dev/null; then
    # List and delete subvolumes
    local subvolumes
    subvolumes=$(btrfs subvolume list "$temp_mount" 2>/dev/null | awk '{print $NF}' | sort -r)

    if [[ -n $subvolumes ]]; then
      while IFS= read -r subvol; do
        log_info "Deleting BTRFS subvolume: $subvol"
        btrfs subvolume delete "$temp_mount/$subvol" 2>/dev/null || log_warn "Failed to delete subvolume: $subvol"
      done <<< "$subvolumes"
    else
      log_info "No BTRFS subvolumes found"
    fi

    # Unmount temporary mount
    umount "$temp_mount"
  else
    log_warn "Could not mount $root_partition for BTRFS cleanup"
  fi

  # Clean up temporary mount point
  rmdir "$temp_mount" 2>/dev/null
}

cleanup_filesystem_signatures() {
  log_info "Wiping filesystem signatures from newly created root partition only..."

  # Only wipe the root partition that we're about to format
  # This prevents destroying Windows/recovery partitions in dual-boot mode
  if [[ -n $ROOT_PARTITION && -b $ROOT_PARTITION ]]; then
    # Check if partition is mounted before wiping
    if mountpoint -q "$ROOT_PARTITION" 2>/dev/null; then
      log_warn "Root partition $ROOT_PARTITION is mounted, skipping wipefs"
      return 0
    fi

    log_info "Wiping filesystem signatures from root partition: $ROOT_PARTITION"
    wipefs -a "$ROOT_PARTITION" 2>/dev/null || log_warn "Failed to wipe signatures from $ROOT_PARTITION"
  else
    log_info "No root partition defined or partition doesn't exist, skipping filesystem signature cleanup"
  fi
}

cleanup_temporary_files() {
  log_info "Cleaning up temporary files and state..."

  # Remove any temporary user override files
  find machines/ -name "_user-override.nix" -delete 2>/dev/null || true

  # Clean up any temporary mount directories
  find /tmp -maxdepth 1 -name "btrfs_cleanup_*" -type d -exec rmdir {} \; 2>/dev/null || true
  find /tmp -maxdepth 1 -name "nixos_install_*" -type d -exec rm -rf {} \; 2>/dev/null || true

  log_info "Temporary files cleaned up"
}

validate_clean_disk_state() {
  log_info "Validating clean disk state..."

  # Check that /mnt is not mounted
  if mountpoint -q /mnt 2>/dev/null; then
    log_error "ERROR: /mnt is still mounted after cleanup"
    return 1
  fi

  # Check for any remaining mounts under /mnt
  local remaining_mounts
  remaining_mounts=$(mount | grep ' /mnt' | wc -l)
  if (( remaining_mounts > 0 )); then
    log_error "ERROR: Found $remaining_mounts remaining mount points under /mnt"
    mount | grep ' /mnt'
    return 1
  fi

  # Verify disk is accessible
  if [[ ! -b $SELECTED_DISK ]]; then
    log_error "ERROR: Selected disk $SELECTED_DISK is not accessible"
    return 1
  fi

  log_info "Disk state validation passed"
}

###############################################################################
# 8.  Device and filesystem helpers
###############################################################################
validate_partition_path() { [[ -b $1 && $1 =~ ^/dev/ ]]; }

wait_for_device() {
  local device=$1
  local timeout=30
  local count=0

  log_info "Waiting for device $device to be ready..."

  while [[ ! -b $device ]] && (( count < timeout )); do
    sleep 1
    ((count++))
  done

  if [[ ! -b $device ]]; then
    log_error "Device $device not available after ${timeout}s"
    return 1
  fi

  # Additional wait for device to be fully ready
  sleep 2
  log_info "Device $device is ready"
  return 0
}

verify_mounts() {
  log_info "Verifying filesystem mounts..."

  # Check that root is mounted
  if ! mountpoint -q /mnt; then
    log_error "Root filesystem not mounted at /mnt"
    return 1
  fi

  # Check that boot is mounted
  if ! mountpoint -q /mnt/boot; then
    log_error "Boot filesystem not mounted at /mnt/boot"
    return 1
  fi

  # For BTRFS, verify subvolume mounts
  if [[ $SELECTED_FILESYSTEM == "btrfs" ]]; then
    local required_mounts=("/mnt/home" "/mnt/nix" "/mnt/.snapshots")
    for mount_point in "${required_mounts[@]}"; do
      if ! mountpoint -q "$mount_point"; then
        log_error "BTRFS subvolume not mounted at $mount_point"
        return 1
      fi
    done
  fi

  # Verify we can write to the mounted filesystems
  local test_file="/mnt/test_write"
  # Set up cleanup trap for test file
  trap 'sudo rm -f "$test_file" 2>/dev/null' RETURN

  if ! sudo touch "$test_file" 2>/dev/null; then
    log_error "Cannot write to root filesystem"
    return 1
  fi
  sudo rm -f "$test_file"

  log_info "All filesystem mounts verified successfully"
  return 0
}

refresh_partition_table() {
  local disk=$1

  log_info "Refreshing partition table for $disk..."

  if is_dry_run; then
    log_info "DRY-RUN: Would refresh partition table"
    return 0
  fi

  # Use multiple methods to ensure partition table is refreshed
  sudo partprobe "$disk" 2>/dev/null || true
  sudo udevadm settle 2>/dev/null || true

  # Give the kernel time to recognize new partitions
  sleep 3

  # Verify partitions are visible
  if ! lsblk "$disk" | grep -q "$(basename "$disk")[0-9]"; then
    log_warn "Partitions not immediately visible, waiting longer..."
    sleep 5
  fi

  log_info "Partition table refresh completed"
}

###############################################################################
# 9.  Partitioning helpers
###############################################################################
partition_disk_fresh() {
  create_fresh_partitions "$SELECTED_DISK"

  # Ensure partition table is refreshed and devices are available
  refresh_partition_table "$SELECTED_DISK"

  ESP_PARTITION="${SELECTED_DISK}1"
  ROOT_PARTITION="${SELECTED_DISK}2"

  # Verify partitions exist
  wait_for_device "$ESP_PARTITION"
  wait_for_device "$ROOT_PARTITION"
}

partition_disk_dual_boot() {
  ESP_PARTITION=$(create_dual_boot_partitions "$SELECTED_DISK")

  # Ensure partition table is refreshed
  refresh_partition_table "$SELECTED_DISK"

  ROOT_PARTITION=$(get_root_partition "$SELECTED_DISK" dual-boot)

  # Verify partitions exist
  wait_for_device "$ESP_PARTITION"
  wait_for_device "$ROOT_PARTITION"
}

partition_disk_manual() {
  echo "Manual partitioning – enter paths:"
  read -rp "ESP partition: " esp
  read -rp "Root partition: " root
  read -rp "Home partition (optional): " home

  validate_partition_path "$esp"  || { echo "Bad ESP"; exit 1; }
  validate_partition_path "$root" || { echo "Bad root"; exit 1; }
  [[ -n $home ]] && ! validate_partition_path "$home" && { echo "Bad home"; exit 1; }

  ESP_PARTITION="$esp"
  ROOT_PARTITION="$root"
  HOME_PARTITION="$home"
}

setup_btrfs() {
  local dev=$1

  # Wait for device to be ready
  wait_for_device "$dev"

  dry_run_cmd sudo mkfs.btrfs -f -L nixos "$dev"

  # Wait for filesystem to be recognized
  sleep 2

  dry_run_cmd sudo mount "$dev" /mnt
  for sv in @root @home @nix @snapshots; do dry_run_cmd sudo btrfs subvolume create /mnt/$sv; done
  dry_run_cmd sudo umount /mnt

  # Wait before remounting
  sleep 1

  dry_run_cmd sudo mount -o subvol=@root,compress=zstd "$dev" /mnt
  dry_run_cmd sudo mkdir -p /mnt/{home,nix,.snapshots,boot}
  dry_run_cmd sudo mount -o subvol=@home,compress=zstd "$dev" /mnt/home
  dry_run_cmd sudo mount -o subvol=@nix,compress=zstd  "$dev" /mnt/nix
  dry_run_cmd sudo mount -o subvol=@snapshots,compress=zstd "$dev" /mnt/.snapshots
}

setup_filesystem() {
  next_step "Create filesystem & mount"
  local part=$ROOT_PARTITION

  # Wait for root partition to be available
  wait_for_device "$ROOT_PARTITION"

  if (( ENABLE_ENCRYPTION )); then
     if [[ -n $LUKS_PASSPHRASE_FILE ]]; then
       # Non-interactive mode with passphrase file
       dry_run_cmd sudo cryptsetup -q luksFormat "$part" --type luks2 --key-file "$LUKS_PASSPHRASE_FILE"
       dry_run_cmd sudo cryptsetup open "$part" cryptroot --key-file "$LUKS_PASSPHRASE_FILE"
     else
       # Interactive mode - prompt for passphrase
       if (( NON_INTERACTIVE )); then
         log_error "Non-interactive encryption requires --luks-pass <file>"
         exit 1
       fi
       dry_run_cmd sudo cryptsetup -q luksFormat "$part" --type luks2
       dry_run_cmd sudo cryptsetup open "$part" cryptroot
     fi
     part=/dev/mapper/cryptroot

     # Wait for encrypted device
     wait_for_device "$part"
  fi

  if [[ $SELECTED_FILESYSTEM == btrfs ]]; then
      setup_btrfs "$part"
  else
      # Wait for device before formatting
      wait_for_device "$part"
      dry_run_cmd sudo mkfs.ext4 -F -L nixos "$part"

      # Wait for filesystem to be recognized
      sleep 2

      dry_run_cmd sudo mount "$part" /mnt
      dry_run_cmd sudo mkdir -p /mnt/boot
  fi

  # Wait for ESP partition and mount
  wait_for_device "$ESP_PARTITION"
  dry_run_cmd sudo mount "$ESP_PARTITION" /mnt/boot

  if [[ -n $HOME_PARTITION ]]; then
      wait_for_device "$HOME_PARTITION"
      dry_run_cmd sudo mkdir -p /mnt/home
      dry_run_cmd sudo mount "$HOME_PARTITION" /mnt/home
  fi

  # Final verification that all mounts are successful
  verify_mounts
}

###############################################################################
# 10.  User override & build validation
###############################################################################
configure_user_override() {
  PRIMARY_USER=${PRIMARY_USER:-$(detect_primary_user_from_flake .)}
  validate_username "$PRIMARY_USER" || { echo "Bad username: $PRIMARY_USER"; exit 1; }

  USER_OVERRIDE=$(setup_user_override "$SELECTED_MACHINE" "$PRIMARY_USER")
}

dry_run_build() {
  next_step "Validate configuration build"
  validate_nix_build ".#nixosConfigurations.$SELECTED_MACHINE.config.system.build.toplevel"
}

###############################################################################
# 11.  HW config & installation
###############################################################################
generate_hw_config() {
  next_step "Generate hardware-configuration.nix"

  if is_dry_run; then
    log_info "DRY-RUN: Would generate hardware configuration"
    return 0
  fi

  # Generate hardware configuration
  sudo nixos-generate-config --root /mnt >/dev/null

  # Validate and fix hardware configuration
  validate_and_fix_hardware_config
}

install_nixos() {
  next_step "nixos-install"

  if is_dry_run; then
     log_info "DRY-RUN: would execute nixos-install"
     return
  fi

  sudo nixos-install --no-root-password --flake ".#$SELECTED_MACHINE" --root /mnt
}

final_validation() {
  if is_dry_run; then
    log_info "DRY-RUN: Would perform final validation"
    return 0
  fi

  # Post-installation validation
  validate_installation

  echo -e "${GREEN}🎉 Installation complete – reboot when ready.${NC}"
}

###############################################################################
# 12.  Post-installation validation
###############################################################################
validate_and_fix_hardware_config() {
  log_info "Validating and fixing hardware configuration..."

  local hw_config="/mnt/etc/nixos/hardware-configuration.nix"

  if [[ ! -f $hw_config ]]; then
    log_error "Hardware configuration not found at $hw_config"
    return 1
  fi

  # Check for correct filesystem UUIDs
  log_info "Verifying filesystem UUIDs in hardware configuration..."

  # Get actual UUIDs from mounted filesystems
  local root_uuid esp_uuid
  root_uuid=$(findmnt -n -o UUID /mnt)
  esp_uuid=$(findmnt -n -o UUID /mnt/boot)

  log_info "Detected UUIDs - Root: $root_uuid, ESP: $esp_uuid"

  # Verify UUIDs exist in hardware config
  if [[ -n $root_uuid ]] && ! grep -q "$root_uuid" "$hw_config"; then
    log_warn "Root filesystem UUID $root_uuid not found in hardware config"
    log_info "This may cause boot failures - attempting minimal fix..."

    # Try minimal patching instead of full regeneration to preserve template overlays
    # Create a backup first
    sudo cp "$hw_config" "${hw_config}.backup"

    # Try to patch the UUID in existing config
    if grep -q "device.*=.*\"/dev/disk/by-uuid/" "$hw_config"; then
      log_info "Attempting to patch existing UUID references..."
      # This is a minimal approach - in production, consider more sophisticated patching
      log_warn "Hardware config UUID mismatch detected but minimal patching not implemented"
      log_warn "Manual verification of hardware-configuration.nix may be required"
    else
      log_warn "Hardware config format not recognized for patching"
      log_warn "Manual verification of hardware-configuration.nix may be required"
    fi
  fi

  # For BTRFS, ensure subvolume options are correct
  if [[ $SELECTED_FILESYSTEM == "btrfs" ]]; then
    log_info "Validating BTRFS subvolume configuration..."

    # Check that subvolume options are present
    if ! grep -q "subvol=@root" "$hw_config"; then
      log_warn "BTRFS subvolume options missing from hardware config"
      fix_btrfs_hardware_config "$hw_config"
    fi
  fi

  log_info "Hardware configuration validation completed"
}

fix_btrfs_hardware_config() {
  local hw_config=$1

  log_info "Fixing BTRFS hardware configuration..."

  # Create a backup
  sudo cp "$hw_config" "${hw_config}.backup"

  # Get the root device UUID
  local root_uuid
  root_uuid=$(findmnt -n -o UUID /mnt)

  if [[ -z $root_uuid ]]; then
    log_error "Cannot determine root filesystem UUID"
    return 1
  fi

  # Create corrected hardware config with proper BTRFS subvolume options
  sudo tee "${hw_config}.new" > /dev/null << EOF
# Do not modify this file!  It was generated by 'nixos-generate-config'
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" ];
  };

  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@snapshots" "compress=zstd" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/$(findmnt -n -o UUID /mnt/boot)";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
EOF

  # Replace the original with the fixed version
  sudo mv "${hw_config}.new" "$hw_config"

  log_info "BTRFS hardware configuration fixed"
}

verify_bootloader_installation() {
  log_info "Verifying bootloader installation..."

  # Check for UEFI bootloader files
  local bootloader_found=false

  if [[ -d /mnt/boot/EFI ]] || [[ -d /mnt/boot/efi ]]; then
    log_info "UEFI bootloader directory found"
    bootloader_found=true

    # Check for systemd-boot
    if [[ -f /mnt/boot/EFI/systemd/systemd-bootx64.efi ]] || [[ -f /mnt/boot/efi/EFI/systemd/systemd-bootx64.efi ]]; then
      log_info "systemd-boot detected"

      # Verify loader entries exist
      local loader_entries_dir="/mnt/boot/loader/entries"
      if [[ -d $loader_entries_dir ]] && [[ -n $(ls -A "$loader_entries_dir" 2>/dev/null) ]]; then
        log_info "Boot entries found"
      else
        log_warn "No boot entries found - this will cause boot failure"
        return 1
      fi

    # Check for GRUB - need more specific detection to avoid Windows false positives
    elif ([[ -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]] || [[ -f /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI ]]) &&
         ([[ -f /mnt/boot/grub/grub.cfg ]] || [[ -f /mnt/boot/EFI/*/grubx64.efi ]] || [[ -f /mnt/boot/efi/EFI/*/grubx64.efi ]]); then
      log_info "GRUB bootloader detected"

    else
      log_warn "UEFI directory exists but no recognized bootloader found"
      bootloader_found=false
    fi
  fi

  if ! $bootloader_found; then
    log_error "No bootloader installation detected - system will not boot"
    log_error "This indicates a serious installation problem"
    return 1
  fi

  log_info "Bootloader verification completed successfully"
  return 0
}

validate_installation() {
  log_info "Performing post-installation validation..."

  # 1. Verify all mount points are accessible
  log_info "Checking mount points..."
  if ! mountpoint -q /mnt; then
    log_error "Root filesystem not mounted at /mnt"
    return 1
  fi

  if ! mountpoint -q /mnt/boot; then
    log_error "Boot filesystem not mounted at /mnt/boot"
    return 1
  fi

  # 2. Verify hardware configuration exists and is valid
  if [[ ! -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
    log_error "Hardware configuration missing"
    return 1
  fi

  # 3. Verify bootloader installation
  log_info "Checking bootloader installation..."
  verify_bootloader_installation

  # 4. Verify filesystem UUIDs match between fstab and actual devices
  log_info "Verifying filesystem UUID consistency..."
  local hw_config="/mnt/etc/nixos/hardware-configuration.nix"
  local root_uuid esp_uuid

  root_uuid=$(findmnt -n -o UUID /mnt)
  esp_uuid=$(findmnt -n -o UUID /mnt/boot)

  if [[ -n $root_uuid ]] && ! grep -q "$root_uuid" "$hw_config"; then
    log_error "Root filesystem UUID mismatch detected"
    return 1
  fi

  if [[ -n $esp_uuid ]] && ! grep -q "$esp_uuid" "$hw_config"; then
    log_error "ESP filesystem UUID mismatch detected"
    return 1
  fi

  # 5. Test that the configuration can be evaluated
  log_info "Testing configuration evaluation..."
  if ! sudo chroot /mnt /run/current-system/sw/bin/nixos-rebuild dry-build --fast &>/dev/null; then
    log_warn "Configuration evaluation test failed - there may be configuration issues"
  fi

  log_info "Post-installation validation completed successfully"
  return 0
}

###############################################################################
# 13.  Main orchestration
###############################################################################
main() {
  parse_arguments "$@"
  calculate_total_steps
  (( QUIET )) || print_header "NixOS Installation Utility" "$SCRIPT_VERSION"

  validate_system
  bootstrap_dependencies
  setup_repository
  discover_machines

  select_installation_mode
  select_machine
  select_filesystem
  select_encryption
  select_disk

  # Clean up any previous installation attempts
  cleanup_previous_installation

  # Partition according to mode
  case $INSTALLATION_MODE in
    fresh)     partition_disk_fresh   ;;
    dual-boot) partition_disk_dual_boot ;;
    manual)    partition_disk_manual  ;;
  esac

  setup_filesystem
  configure_user_override
  dry_run_build
  generate_hw_config
  install_nixos
  final_validation
  cleanup_and_exit 0
}

main "$@"
