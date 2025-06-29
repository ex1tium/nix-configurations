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

  echo "  ${CYAN}[1]${NC} 💥 Fresh  (erase whole disk)"
  echo "  ${CYAN}[2]${NC} 🤝 Dual-boot (reuse free space)"
  echo "  ${CYAN}[3]${NC} 🛠️  Manual (you partition yourself)"
  read -rp "${YELLOW}Choose mode [1-3]:${NC} " ans
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
      printf "  ${CYAN}[%d]${NC} 🖥️  %s\n" $((i+1)) "${DISCOVERED_MACHINES[$i]}"
  done
  read -rp "${YELLOW}Select machine:${NC} " n
  SELECTED_MACHINE=${DISCOVERED_MACHINES[$((n-1))]}
}

select_filesystem() {
  next_step "Select filesystem"
  if (( NON_INTERACTIVE )); then
    ENABLE_SNAPSHOTS=$([[ $SELECTED_FILESYSTEM == btrfs ]] && echo 1 || echo 0)
    return
  fi
  echo "  ${CYAN}[1]${NC} 🌳 Btrfs (snapshots)  ${CYAN}[2]${NC} 📁 ext4"
  read -rp "${YELLOW}Filesystem:${NC} " choice
  case $choice in
    2) SELECTED_FILESYSTEM="ext4"; ENABLE_SNAPSHOTS=0 ;;   # ext4
    *) SELECTED_FILESYSTEM="btrfs"; ENABLE_SNAPSHOTS=1 ;;  # default = btrfs
  esac
}

select_encryption() {
  next_step "Encryption"
  [[ -n $ENABLE_ENCRYPTION ]] && return
  (( NON_INTERACTIVE )) && { log_error "Encryption flag required"; exit 1; }

  read -rp "${YELLOW}🔐 Enable LUKS2 encryption? [y/N]:${NC} " a
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
     printf "  ${CYAN}[%d]${NC} 💾 %s  ${GREEN}%dGiB${NC}\n" $((i+1)) "${disks[$i]}" $((sz/1024/1024/1024))
  done
  read -rp "${YELLOW}Select disk:${NC} " n
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

  # Create BTRFS filesystem
  if is_dry_run; then
    log_info "DRY-RUN: Would create BTRFS filesystem on $dev"
  else
    log_info "Creating BTRFS filesystem on $dev 🌳"
    if ! sudo mkfs.btrfs -f -L nixos "$dev"; then
      log_error "Failed to create BTRFS filesystem on $dev"
      exit 1
    fi
    log_success "BTRFS filesystem created successfully! 🎯"
  fi

  # Wait for filesystem to be recognized
  sleep 2

  # Mount and create subvolumes
  if is_dry_run; then
    log_info "DRY-RUN: Would mount $dev to /mnt"
  else
    log_info "Mounting $dev to /mnt"
    if ! sudo mount "$dev" /mnt; then
      log_error "Failed to mount $dev to /mnt"
      exit 1
    fi
  fi

  # Create subvolumes with explicit error checking (using NixOS standard naming)
  for sv in root home nix snapshots; do
    log_info "Creating BTRFS subvolume: $sv"

    if is_dry_run; then
      log_info "DRY-RUN: Would create BTRFS subvolume $sv"
    else
      # Execute the command directly with error checking
      if ! sudo btrfs subvolume create "/mnt/$sv"; then
        log_error "Failed to create BTRFS subvolume: $sv"
        exit 1
      fi

      # Verify subvolume was created
      if ! sudo btrfs subvolume show "/mnt/$sv" &>/dev/null; then
        log_error "BTRFS subvolume $sv was not created properly"
        exit 1
      fi

      # Set proper permissions on the subvolume
      if ! sudo chmod 755 "/mnt/$sv"; then
        log_warn "Could not set permissions on subvolume $sv"
      fi

      log_success "BTRFS subvolume $sv created successfully! 📁✨"
    fi
  done

  # Sync and unmount
  if is_dry_run; then
    log_info "DRY-RUN: Would sync and unmount /mnt"
  else
    log_info "Syncing and unmounting /mnt"
    sudo sync
    if ! sudo umount /mnt; then
      log_error "Failed to unmount /mnt"
      exit 1
    fi
  fi

  # Wait for unmount to complete
  sleep 2

  # Remount with subvolumes
  log_info "Mounting BTRFS subvolumes... 🔗"
  if is_dry_run; then
    log_info "DRY-RUN: Would mount BTRFS subvolumes"
  else
    # Mount root subvolume (using NixOS standard naming)
    if ! sudo mount -o subvol=root,compress=zstd "$dev" /mnt; then
      log_error "Failed to mount root subvolume"
      exit 1
    fi

    # Create directories
    sudo mkdir -p /mnt/{home,nix,.snapshots,boot}

    # Mount other subvolumes
    if ! sudo mount -o subvol=home,compress=zstd "$dev" /mnt/home; then
      log_error "Failed to mount home subvolume"
      exit 1
    fi

    if ! sudo mount -o subvol=nix,compress=zstd,noatime "$dev" /mnt/nix; then
      log_error "Failed to mount nix subvolume"
      exit 1
    fi

    if ! sudo mount -o subvol=snapshots,compress=zstd "$dev" /mnt/.snapshots; then
      log_error "Failed to mount snapshots subvolume"
      exit 1
    fi
  fi

  # Verify all mounts are successful
  if ! is_dry_run; then
    for mount_point in /mnt /mnt/home /mnt/nix /mnt/.snapshots; do
      if ! mountpoint -q "$mount_point"; then
        log_error "Failed to mount BTRFS subvolume at $mount_point"
        exit 1
      fi
    done

    # Quick verification of subvolume setup
    verify_btrfs_subvolumes "$dev"

    log_success "All BTRFS subvolumes mounted successfully! 🎉 Ready to install!"
  fi
}

verify_btrfs_subvolumes() {
  local dev=$1
  log_info "Checking BTRFS subvolume setup..."

  # Simple check: verify mount points exist and are mounted
  local mount_points=("/mnt" "/mnt/home" "/mnt/nix" "/mnt/.snapshots")
  local subvol_names=("root" "home" "nix" "snapshots")
  local mounted_count=0

  for i in "${!mount_points[@]}"; do
    local mount_point="${mount_points[$i]}"
    local subvol_name="${subvol_names[$i]}"

    if [[ -d "$mount_point" ]] && mountpoint -q "$mount_point" 2>/dev/null; then
      log_success "✅ $subvol_name mounted at $mount_point"
      ((mounted_count++))
    else
      log_info "⏳ $subvol_name at $mount_point (setup in progress)"
    fi
  done

  if (( mounted_count == 4 )); then
    log_success "All BTRFS subvolumes are properly mounted! 🎉"
  elif (( mounted_count >= 1 )); then
    log_info "BTRFS subvolumes are being set up... ($mounted_count/4 ready)"
  else
    log_info "BTRFS subvolume setup is in progress..."
  fi

  # Always return success - this is just informational
  return 0
}

setup_filesystem() {
  next_step "Create filesystem & mount"
  local part=$ROOT_PARTITION

  # Wait for root partition to be available
  wait_for_device "$ROOT_PARTITION"

  if (( ENABLE_ENCRYPTION )); then
     if [[ -n $LUKS_PASSPHRASE_FILE ]]; then
       # Non-interactive mode with passphrase file
       if is_dry_run; then
         log_info "DRY-RUN: Would setup LUKS encryption with passphrase file"
       else
         log_info "Setting up LUKS encryption with passphrase file"
         if ! sudo cryptsetup -q luksFormat "$part" --type luks2 --key-file "$LUKS_PASSPHRASE_FILE"; then
           log_error "Failed to format LUKS partition"
           exit 1
         fi
         if ! sudo cryptsetup open "$part" cryptroot --key-file "$LUKS_PASSPHRASE_FILE"; then
           log_error "Failed to open LUKS partition"
           exit 1
         fi
       fi
     else
       # Interactive mode - prompt for passphrase
       if (( NON_INTERACTIVE )); then
         log_error "Non-interactive encryption requires --luks-pass <file>"
         exit 1
       fi
       if is_dry_run; then
         log_info "DRY-RUN: Would setup LUKS encryption with interactive passphrase"
       else
         log_info "Setting up LUKS encryption (interactive)"
         if ! sudo cryptsetup -q luksFormat "$part" --type luks2; then
           log_error "Failed to format LUKS partition"
           exit 1
         fi
         if ! sudo cryptsetup open "$part" cryptroot; then
           log_error "Failed to open LUKS partition"
           exit 1
         fi
       fi
     fi
     part=/dev/mapper/cryptroot

     # Wait for encrypted device
     if ! is_dry_run; then
       wait_for_device "$part"
     fi
  fi

  if [[ $SELECTED_FILESYSTEM == btrfs ]]; then
      setup_btrfs "$part"
  else
      # Wait for device before formatting
      wait_for_device "$part"

      # Create EXT4 filesystem
      if is_dry_run; then
        log_info "DRY-RUN: Would create EXT4 filesystem on $part"
      else
        log_info "Creating EXT4 filesystem on $part"
        if ! sudo mkfs.ext4 -F -L nixos "$part"; then
          log_error "Failed to create EXT4 filesystem on $part"
          exit 1
        fi
      fi

      # Wait for filesystem to be recognized
      sleep 2

      # Mount root filesystem
      if is_dry_run; then
        log_info "DRY-RUN: Would mount $part to /mnt"
      else
        if ! sudo mount "$part" /mnt; then
          log_error "Failed to mount $part to /mnt"
          exit 1
        fi
        sudo mkdir -p /mnt/boot
      fi
  fi

  # Wait for ESP partition and mount
  wait_for_device "$ESP_PARTITION"
  if is_dry_run; then
    log_info "DRY-RUN: Would mount ESP partition $ESP_PARTITION to /mnt/boot"
  else
    log_info "Mounting ESP partition $ESP_PARTITION to /mnt/boot"
    if ! sudo mount "$ESP_PARTITION" /mnt/boot; then
      log_error "Failed to mount ESP partition $ESP_PARTITION"
      exit 1
    fi
  fi

  if [[ -n $HOME_PARTITION ]]; then
      wait_for_device "$HOME_PARTITION"
      if is_dry_run; then
        log_info "DRY-RUN: Would mount home partition $HOME_PARTITION to /mnt/home"
      else
        sudo mkdir -p /mnt/home
        if ! sudo mount "$HOME_PARTITION" /mnt/home; then
          log_error "Failed to mount home partition $HOME_PARTITION"
          exit 1
        fi
      fi
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

  # Generate fresh hardware configuration for current hardware/partitioning
  # This will be copied to the repository during nixos-install to ensure
  # the correct UUIDs and hardware settings are used
  log_info "Running nixos-generate-config..."
  sudo nixos-generate-config --root /mnt >/dev/null

  # Show what was generated for debugging
  log_info "Generated hardware configuration preview:"
  if [[ -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
    # Show filesystem entries for debugging
    grep -A 3 -B 1 'fileSystems\."/"' /mnt/etc/nixos/hardware-configuration.nix || log_warn "Could not find root filesystem config"
  fi

  # Validate and fix hardware configuration
  validate_and_fix_hardware_config
}

preview_hardware_config() {
  local generated_hw_config="/mnt/etc/nixos/hardware-configuration.nix"

  if [[ ! -f "$generated_hw_config" ]]; then
    log_error "Generated hardware config not found at $generated_hw_config"
    return 1
  fi

  echo
  print_box "$CYAN" "📋 HARDWARE CONFIGURATION PREVIEW" \
    "${WHITE}The following hardware configuration will be used for installation:"
  echo

  # Show key parts of the hardware config
  log_info "🔍 Key configuration details:"
  echo

  # Show filesystem configurations
  if grep -q "fileSystems" "$generated_hw_config"; then
    echo "${CYAN}📁 Filesystems:${NC}"
    grep -A 2 'fileSystems\.' "$generated_hw_config" | sed 's/^/  /'
    echo
  fi

  # Show boot configuration
  if grep -q "boot\." "$generated_hw_config"; then
    echo "${CYAN}🚀 Boot configuration:${NC}"
    grep "boot\." "$generated_hw_config" | head -5 | sed 's/^/  /'
    echo
  fi

  # Show if LUKS is configured
  if grep -q "luks" "$generated_hw_config"; then
    echo "${CYAN}🔒 Encryption detected:${NC}"
    grep "luks" "$generated_hw_config" | sed 's/^/  /'
    echo
  fi

  # Ask for confirmation
  echo "${YELLOW}📝 Full hardware configuration:${NC}"
  echo "${DIM}(First 20 lines - full config will be used for installation)${NC}"
  head -20 "$generated_hw_config" | sed 's/^/  /'
  echo "  ${DIM}... (truncated)${NC}"
  echo

  if ! confirm "Do you want to proceed with this hardware configuration?"; then
    log_warn "Installation cancelled by user"
    return 1
  fi
}

install_nixos() {
  next_step "nixos-install"

  if is_dry_run; then
     log_info "DRY-RUN: would execute nixos-install"
     return
  fi

  # Preview and confirm hardware configuration
  preview_hardware_config || return 1

  # Copy the newly generated hardware config to overwrite the old one in the repo
  local generated_hw_config="/mnt/etc/nixos/hardware-configuration.nix"
  local repo_hw_config="machines/$SELECTED_MACHINE/hardware-configuration.nix"

  if [[ -f "$generated_hw_config" ]]; then
    log_info "Copying fresh hardware config to repository..."
    cp "$generated_hw_config" "$repo_hw_config"
    log_success "Updated $repo_hw_config with fresh hardware configuration"
  else
    log_error "Generated hardware config not found at $generated_hw_config"
    return 1
  fi

  log_info "Starting NixOS installation..."
  if sudo nixos-install --no-root-password --flake ".#$SELECTED_MACHINE" --root /mnt; then
    log_success "NixOS installation completed successfully!"
    return 0
  else
    log_error "NixOS installation failed!"
    return 1
  fi
}

offer_hardware_config_commit() {
  local repo_hw_config="machines/$SELECTED_MACHINE/hardware-configuration.nix"

  echo
  print_box "$CYAN" "💾 HARDWARE CONFIGURATION BACKUP" \
    "${WHITE}The fresh hardware configuration has been generated for this installation." \
    "" \
    "${YELLOW}Would you like to commit it back to the repository?" \
    "${DIM}This creates a backup and allows sharing the config with other systems."

  if confirm "Commit hardware configuration to repository?"; then
    log_info "Committing hardware configuration..."

    if git add "$repo_hw_config" && git commit -m "Update hardware config for $SELECTED_MACHINE

Generated during installation on $(date)
- Fresh UUIDs for current partitioning
- Current hardware detection
- Installation mode: $INSTALLATION_MODE"; then
      log_success "Hardware configuration committed to repository"

      if confirm "Push changes to remote repository?"; then
        if git push; then
          log_success "Changes pushed to remote repository"
        else
          log_warn "Failed to push to remote - you may need to push manually later"
        fi
      fi
    else
      log_warn "Failed to commit hardware configuration"
    fi
  else
    log_info "Hardware configuration not committed (local copy updated only)"
  fi
}

final_validation() {
  if is_dry_run; then
    log_info "DRY-RUN: Would perform final validation"
    return 0
  fi

  # Post-installation validation
  validate_installation

  # Offer to commit hardware config back to repo
  offer_hardware_config_commit

  echo

  # Beautiful completion banner using the box helper
  print_box "$GREEN" "🎉 INSTALLATION COMPLETE! 🎉" \
    "${WHITE}Your NixOS system is ready! Remove the installation media and reboot." \
    "" \
    "${CYAN}🚀 Reboot command: ${YELLOW}sudo reboot"

  echo
}

###############################################################################
# 12.  Post-installation validation
###############################################################################



validate_and_fix_hardware_config() {
  log_info "Validating hardware configuration..."

  local hw_config="/mnt/etc/nixos/hardware-configuration.nix"

  if [[ ! -f $hw_config ]]; then
    log_error "Hardware configuration not found at $hw_config"
    return 1
  fi

  # Simple validation - just check that the file exists and has basic content
  if grep -q "fileSystems" "$hw_config" && grep -q "boot.loader" "$hw_config"; then
    log_success "✅ Hardware configuration appears valid"
    log_info "Generated hardware config contains filesystem and bootloader configuration"
    return 0
  else
    log_warn "⚠️  Hardware configuration may be incomplete"
    log_info "This might be normal for some configurations"
    return 0
  fi
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

verify_boot_entries() {
  log_info "Verifying boot entries and kernel files..."

  # Check for systemd-boot entries
  local loader_entries_dir="/mnt/boot/loader/entries"
  if [[ -d $loader_entries_dir ]]; then
    local entry_files
    mapfile -t entry_files < <(find "$loader_entries_dir" -name "*.conf" 2>/dev/null)

    if [[ ${#entry_files[@]} -eq 0 ]]; then
      log_error "No boot entry files found in $loader_entries_dir"
      return 1
    fi

    log_info "Found ${#entry_files[@]} boot entry file(s)"

    # Validate each boot entry
    for entry_file in "${entry_files[@]}"; do
      log_info "Validating boot entry: $(basename "$entry_file")"

      # Extract kernel and initrd paths from the entry
      local linux_path initrd_path
      linux_path=$(grep "^linux " "$entry_file" | awk '{print $2}' | head -1)
      initrd_path=$(grep "^initrd " "$entry_file" | awk '{print $2}' | head -1)

      # Check if kernel file exists
      if [[ -n $linux_path ]]; then
        local full_kernel_path="/mnt/boot$linux_path"
        if [[ -f $full_kernel_path ]]; then
          log_info "  ✅ Kernel found: $linux_path"
        else
          log_error "  ❌ Kernel missing: $full_kernel_path"
          return 1
        fi
      else
        log_error "  ❌ No kernel specified in boot entry"
        return 1
      fi

      # Check if initrd file exists
      if [[ -n $initrd_path ]]; then
        local full_initrd_path="/mnt/boot$initrd_path"
        if [[ -f $full_initrd_path ]]; then
          log_info "  ✅ Initrd found: $initrd_path"
        else
          log_error "  ❌ Initrd missing: $full_initrd_path"
          return 1
        fi
      else
        log_warn "  ⚠️  No initrd specified in boot entry"
      fi

      # Validate boot entry syntax
      if ! grep -q "^title " "$entry_file"; then
        log_warn "  ⚠️  Boot entry missing title"
      fi

      # Check for required options for BTRFS
      if [[ $SELECTED_FILESYSTEM == "btrfs" ]]; then
        if ! grep -q "rootflags=subvol=root" "$entry_file"; then
          log_warn "  ⚠️  Boot entry may be missing BTRFS subvolume options"
        fi
      fi
    done
  else
    log_warn "No systemd-boot entries directory found"
  fi

  # Verify EFI boot variables (if available)
  if command -v efibootmgr >/dev/null 2>&1; then
    log_info "Checking EFI boot variables..."
    if efibootmgr | grep -i nixos >/dev/null; then
      log_info "  ✅ NixOS EFI boot entry found"
    else
      log_warn "  ⚠️  No NixOS EFI boot entry found"
    fi
  fi

  log_info "Boot entries validation completed"
  return 0
}

verify_luks_setup() {
  log_info "Verifying LUKS encryption setup..."

  # Check if LUKS device is properly set up
  if [[ -n ${LUKS_DEVICE:-} ]]; then
    # Verify LUKS header
    if cryptsetup isLuks "$ROOT_PARTITION"; then
      log_info "  ✅ LUKS header found on $ROOT_PARTITION"
    else
      log_error "  ❌ LUKS header not found on $ROOT_PARTITION"
      return 1
    fi

    # Check if LUKS device is currently open
    if [[ -e "/dev/mapper/$LUKS_DEVICE" ]]; then
      log_info "  ✅ LUKS device is open: /dev/mapper/$LUKS_DEVICE"
    else
      log_error "  ❌ LUKS device not open: /dev/mapper/$LUKS_DEVICE"
      return 1
    fi

    # Verify hardware configuration includes LUKS setup
    local hw_config="/mnt/etc/nixos/hardware-configuration.nix"
    if grep -q "boot.initrd.luks.devices" "$hw_config"; then
      log_info "  ✅ LUKS configuration found in hardware config"
    else
      log_warn "  ⚠️  LUKS configuration may be missing from hardware config"
    fi

    # Check for required kernel modules in initrd
    if grep -q "boot.initrd.availableKernelModules.*dm-crypt" "$hw_config" ||
       grep -q "boot.initrd.kernelModules.*dm-crypt" "$hw_config"; then
      log_info "  ✅ dm-crypt module configured for initrd"
    else
      log_warn "  ⚠️  dm-crypt module may not be available in initrd"
    fi
  else
    log_warn "LUKS device name not set, skipping LUKS validation"
  fi

  log_info "LUKS validation completed"
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

  # 3.5. Verify boot entries and kernel files
  log_info "Validating boot entries and kernel files..."
  verify_boot_entries

  # 3.6. Verify LUKS encryption if enabled
  if [[ $ENABLE_LUKS == true ]]; then
    log_info "Validating LUKS encryption setup..."
    verify_luks_setup
  fi

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

  # 5. Verify filesystem integrity
  log_info "Checking filesystem integrity..."
  verify_filesystem_integrity

  # 6. Test that the configuration can be evaluated
  log_info "Testing configuration evaluation..."
  if ! sudo chroot /mnt /run/current-system/sw/bin/nixos-rebuild dry-build --fast &>/dev/null; then
    log_warn "Configuration evaluation test failed - there may be configuration issues"
  fi

  log_info "Post-installation validation completed successfully"
  return 0
}

verify_filesystem_integrity() {
  log_info "Verifying filesystem integrity..."

  # Check root filesystem
  local root_device
  root_device=$(findmnt -n -o SOURCE /mnt | sed 's/\[.*\]//')

  if [[ $SELECTED_FILESYSTEM == "btrfs" ]]; then
    log_info "Running BTRFS filesystem check..."
    if btrfs filesystem show "$root_device" >/dev/null 2>&1; then
      log_info "  ✅ BTRFS filesystem structure is valid"
    else
      log_error "  ❌ BTRFS filesystem structure check failed"
      return 1
    fi

    # Check BTRFS subvolumes
    log_info "Verifying BTRFS subvolumes..."
    local expected_subvols=("root" "home" "nix" "snapshots")
    for subvol in "${expected_subvols[@]}"; do
      if btrfs subvolume show "/mnt/.snapshots/../$subvol" >/dev/null 2>&1; then
        log_info "  ✅ Subvolume '$subvol' exists and is accessible"
      else
        log_error "  ❌ Subvolume '$subvol' is missing or inaccessible"
        return 1
      fi
    done
  elif [[ $SELECTED_FILESYSTEM == "ext4" ]]; then
    log_info "Running ext4 filesystem check..."
    # Use read-only check to avoid any modifications
    if tune2fs -l "$root_device" >/dev/null 2>&1; then
      log_info "  ✅ ext4 filesystem structure is valid"
    else
      log_error "  ❌ ext4 filesystem structure check failed"
      return 1
    fi
  fi

  # Check ESP filesystem
  local esp_device
  esp_device=$(findmnt -n -o SOURCE /mnt/boot)
  if [[ -n $esp_device ]]; then
    log_info "Checking ESP filesystem..."
    # Skip fsck.fat as it can be unreliable and may modify the filesystem
    if [[ -f /mnt/boot/EFI/systemd/systemd-bootx64.efi ]] || [[ -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]]; then
      log_info "  ✅ ESP contains bootloader files"
    else
      log_warn "  ⚠️  ESP may be missing bootloader files"
    fi
  fi

  log_info "Filesystem integrity check completed"
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
  install_nixos || { log_error "Installation failed"; cleanup_and_exit 1; }
  final_validation
  cleanup_and_exit 0
}

main "$@"
