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
readonly TOTAL_STEPS=13

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
     local rc=$?
     if (( rc == 2 )); then
        exec nix-shell -p "${pkgs[@]}" --run "bash \"$0\" ${ORIGINAL_ARGS[*]}"
     fi
     exit $rc
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
     size=$(lsblk -bn -o SIZE "${disks[$i]}"); size=$((size/1024/1024/1024))
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
# 7.  Partitioning helpers
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
  print_step 11 "$TOTAL_STEPS" "Create filesystem & mount"
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
# 8.  User override & build validation
###############################################################################
configure_user_override() {
  PRIMARY_USER=${PRIMARY_USER:-$(detect_primary_user_from_flake .)}
  validate_username "$PRIMARY_USER" || { echo "Bad username: $PRIMARY_USER"; exit 1; }

  USER_OVERRIDE=$(setup_user_override "$SELECTED_MACHINE" "$PRIMARY_USER")
}

dry_run_build() {
  print_step 10 "$TOTAL_STEPS" "Validate configuration build"
  validate_nix_build ".#nixosConfigurations.$SELECTED_MACHINE.config.system.build.toplevel"
}

###############################################################################
# 9.  HW config & installation
###############################################################################
generate_hw_config() {
  print_step 12 "$TOTAL_STEPS" "Generate hardware-configuration.nix"
  dry_run_cmd sudo nixos-generate-config --root /mnt >/dev/null
}

install_nixos() {
  print_step 13 "$TOTAL_STEPS" "nixos-install"

  if is_dry_run; then
     log_info "DRY-RUN: would execute nixos-install"
     return
  fi

  sudo nixos-install --no-root-password --flake ".#$SELECTED_MACHINE" --root /mnt
  echo -e "${GREEN}🎉 Installation complete – reboot when ready.${NC}"
}

###############################################################################
# 10.  Main orchestration
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
