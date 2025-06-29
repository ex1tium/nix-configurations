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
readonly TOTAL_STEPS=14

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
      (( ${#miss[@]} )) && { echo "Missing flags in non-interactive mode: ${miss[*]}"; exit 1; }
  fi

  export DRY_RUN NON_INTERACTIVE QUIET DEBUG
}

###############################################################################
# 3.  Error handling / cleanup
###############################################################################
cleanup_and_exit() {
  local code=${1:-0}
  [[ -n ${USER_OVERRIDE:-} && -f $USER_OVERRIDE ]] && rm -f "$USER_OVERRIDE"
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
  print_step 1 "$TOTAL_STEPS" "System validation"
  validate_installation_environment
}

bootstrap_dependencies() {
  print_step 2 "$TOTAL_STEPS" "Dependency bootstrap"
  local pkgs=(git parted util-linux gptfdisk cryptsetup rsync tar jq bc)

  if ! bootstrap_nix_dependencies "${pkgs[@]}"; then
     log_error "Dependency check failed. Exiting."
     cleanup_and_exit 1
  fi
}

###############################################################################
# 5.  Repository & machine discovery
###############################################################################
setup_repository() {
  print_step 3 "$TOTAL_STEPS" "Clone configuration repository"
  setup_config_repository "$REPO_URL" "$REPO_BRANCH" /tmp/nix-config
  cd /tmp/nix-config
}

discover_machines() {
  print_step 4 "$TOTAL_STEPS" "Discover machine configurations"
  mapfile -t DISCOVERED_MACHINES < <(discover_machine_configs machines)
}

###############################################################################
# 6.  Interactive selections
###############################################################################
select_installation_mode() {
  print_step 5 "$TOTAL_STEPS" "Select installation mode"
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
  print_step 6 "$TOTAL_STEPS" "Select machine"
  [[ -n $SELECTED_MACHINE ]] && return
  (( NON_INTERACTIVE )) && { log_error "Machine required"; exit 1; }
  for i in "${!DISCOVERED_MACHINES[@]}"; do
      printf "  [%d] %s\n" $((i+1)) "${DISCOVERED_MACHINES[$i]}"
  done
  read -rp "Machine: " n
  SELECTED_MACHINE=${DISCOVERED_MACHINES[$((n-1))]}
}

select_filesystem() {
  print_step 7 "$TOTAL_STEPS" "Select filesystem"
  # Skip if filesystem already set via CLI
  [[ $SELECTED_FILESYSTEM != "btrfs" ]] && { ENABLE_SNAPSHOTS=0; return; }
  (( NON_INTERACTIVE )) && { ENABLE_SNAPSHOTS=$([[ $SELECTED_FILESYSTEM == btrfs ]]&&echo 1||echo 0); return; }

  echo "  [1] Btrfs (snapshots)  [2] ext4"
  read -rp "FS: " f
  if [[ $f == 2 ]]; then
      SELECTED_FILESYSTEM="ext4"
      ENABLE_SNAPSHOTS=0
  else
      SELECTED_FILESYSTEM="btrfs"
      ENABLE_SNAPSHOTS=1
  fi
}

select_encryption() {
  print_step 8 "$TOTAL_STEPS" "Encryption"
  [[ -n $ENABLE_ENCRYPTION ]] && return
  (( NON_INTERACTIVE )) && { log_error "Encryption flag required"; exit 1; }

  read -rp "Enable LUKS2? [y/N]: " a
  ENABLE_ENCRYPTION=$([[ ${a,,} == y* ]] && echo 1 || echo 0)
}

select_disk() {
  print_step 9 "$TOTAL_STEPS" "Disk selection"
  [[ -n $SELECTED_DISK ]] && return
  (( NON_INTERACTIVE )) && { log_error "Disk required"; exit 1; }

  mapfile -t disks < <(list_disks)
  for i in "${!disks[@]}"; do
     size=$(lsblk -bn -o SIZE "${disks[$i]}" | head -1)
     # Ensure size is a valid number and handle potential whitespace/formatting issues
     size=${size//[^0-9]/}
     size=$((size/1024/1024/1024))
     printf "  [%d] %s  %dGiB\n" $((i+1)) "${disks[$i]}" "$size"
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
  print_step 10 "$TOTAL_STEPS" "Clean up previous installation attempts"

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

  local root_partition="${SELECTED_DISK}2"

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
  log_info "Wiping filesystem signatures from target disk partitions..."

  # Get all partitions on the target disk
  local partitions
  partitions=$(lsblk -ln -o NAME "$SELECTED_DISK" | grep -v "^$(basename "$SELECTED_DISK")$" | sed "s|^|/dev/|")

  if [[ -n $partitions ]]; then
    while IFS= read -r partition; do
      if [[ -b $partition ]]; then
        log_info "Wiping filesystem signatures from: $partition"
        wipefs -a "$partition" 2>/dev/null || log_warn "Failed to wipe signatures from $partition"
      fi
    done <<< "$partitions"
  else
    log_info "No existing partitions found on $SELECTED_DISK"
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
# 8.  Partitioning helpers
###############################################################################
partition_disk_fresh() {
  create_fresh_partitions "$SELECTED_DISK"
  ESP_PARTITION="${SELECTED_DISK}1"
  ROOT_PARTITION="${SELECTED_DISK}2"
}

partition_disk_dual_boot() {
  ESP_PARTITION=$(create_dual_boot_partitions "$SELECTED_DISK")
  ROOT_PARTITION=$(get_root_partition "$SELECTED_DISK" dual-boot)
}

partition_disk_manual() {
  echo "Manual partitioning – enter paths:"
  read -rp "ESP partition: " esp
  read -rp "Root partition: " root
  read -rp "Home partition (optional): " home

  validate_disk_device "$esp"  || { echo "Bad ESP"; exit 1; }
  validate_disk_device "$root" || { echo "Bad root"; exit 1; }
  [[ -n $home ]] && ! validate_disk_device "$home" && { echo "Bad home"; exit 1; }

  ESP_PARTITION="$esp"
  ROOT_PARTITION="$root"
  HOME_PARTITION="$home"
}

setup_btrfs() {
  local dev=$1
  dry_run_cmd sudo mkfs.btrfs -f -L nixos "$dev"
  dry_run_cmd sudo mount "$dev" /mnt
  for sv in @root @home @nix @snapshots; do dry_run_cmd sudo btrfs subvolume create /mnt/$sv; done
  dry_run_cmd sudo umount /mnt

  dry_run_cmd sudo mount -o subvol=@root,compress=zstd "$dev" /mnt
  dry_run_cmd sudo mkdir -p /mnt/{home,nix,.snapshots,boot}
  dry_run_cmd sudo mount -o subvol=@home,compress=zstd "$dev" /mnt/home
  dry_run_cmd sudo mount -o subvol=@nix,compress=zstd  "$dev" /mnt/nix
  dry_run_cmd sudo mount -o subvol=@snapshots,compress=zstd "$dev" /mnt/.snapshots
}

setup_filesystem() {
  print_step 12 "$TOTAL_STEPS" "Create filesystem & mount"
  local part=$ROOT_PARTITION

  if (( ENABLE_ENCRYPTION )); then
     dry_run_cmd sudo cryptsetup -q luksFormat "$part" --type luks2
     dry_run_cmd sudo cryptsetup open "$part" cryptroot
     part=/dev/mapper/cryptroot
  fi

  if [[ $SELECTED_FILESYSTEM == btrfs ]]; then
      setup_btrfs "$part"
  else
      dry_run_cmd sudo mkfs.ext4 -F -L nixos "$part"
      dry_run_cmd sudo mount "$part" /mnt
      dry_run_cmd sudo mkdir -p /mnt/boot
  fi

  dry_run_cmd sudo mount "$ESP_PARTITION" /mnt/boot

  if [[ -n $HOME_PARTITION ]]; then
      dry_run_cmd sudo mkdir -p /mnt/home
      dry_run_cmd sudo mount "$HOME_PARTITION" /mnt/home
  fi
}

###############################################################################
# 9.  User override & build validation
###############################################################################
configure_user_override() {
  PRIMARY_USER=${PRIMARY_USER:-$(detect_primary_user_from_flake .)}
  validate_username "$PRIMARY_USER" || { echo "Bad username: $PRIMARY_USER"; exit 1; }

  USER_OVERRIDE=$(setup_user_override "$SELECTED_MACHINE" "$PRIMARY_USER")
}

dry_run_build() {
  print_step 11 "$TOTAL_STEPS" "Validate configuration build"
  validate_nix_build ".#nixosConfigurations.$SELECTED_MACHINE.config.system.build.toplevel"
}

###############################################################################
# 10.  HW config & installation
###############################################################################
generate_hw_config() {
  print_step 13 "$TOTAL_STEPS" "Generate hardware-configuration.nix"
  dry_run_cmd sudo nixos-generate-config --root /mnt >/dev/null
}

install_nixos() {
  print_step 14 "$TOTAL_STEPS" "nixos-install"

  if is_dry_run; then
     log_info "DRY-RUN: would execute nixos-install"
     return
  fi

  sudo nixos-install --no-root-password --flake ".#$SELECTED_MACHINE" --root /mnt
  echo -e "${GREEN}🎉 Installation complete – reboot when ready.${NC}"
}

###############################################################################
# 11.  Main orchestration
###############################################################################
main() {
  parse_arguments "$@"
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
  cleanup_and_exit 0
}

main "$@"
