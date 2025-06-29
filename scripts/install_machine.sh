#!/usr/bin/env -S bash -Eeuo pipefail
# ──────────────────────────────────────────────────────────────────────────────
#  « install_machine.sh » – Generic NixOS installer (Btrfs / ext4 only)
# ──────────────────────────────────────────────────────────────────────────────
#   ▸ Interactive or fully non-interactive          ▸ Optional LUKS2
#   ▸ Btrfs snapshots out-of-the-box (if Btrfs)      ▸ Robust logging & dry-run
#   ▸ Generates hardware-configuration.nix           ▸ Shared helpers via lib/common.sh
# ──────────────────────────────────────────────────────────────────────────────

shopt -s inherit_errexit lastpipe
IFS=$'\n\t'

###############################################################################
# 0.  Paths & shared helpers
###############################################################################
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOG_FILE="/tmp/nixos-install-$(date +%Y%m%d-%H%M%S).log"; export LOG_FILE
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

###############################################################################
# 1.  Globals
###############################################################################
readonly SCRIPT_VERSION="2.3.0"
readonly REPO_URL_DEFAULT="https://github.com/ex1tium/nix-configurations.git"

REPO_URL=$REPO_URL_DEFAULT;  REPO_BRANCH="main"
SELECTED_FILESYSTEM="btrfs"   # btrfs | ext4
ENABLE_SNAPSHOTS=1            # toggled by FS menu
ENABLE_ENCRYPTION=""          # "",1,0
SELECTED_MACHINE=""  SELECTED_DISK=""  PRIMARY_USER=""

DRY_RUN=0 NON_INTERACTIVE=0 QUIET=0 DEBUG=0 FORCE_YES=0
readonly ORIGINAL_ARGS=("$@")
readonly NIX_FLAGS="$(get_nix_flags)"

###############################################################################
# 2.  CLI
###############################################################################
usage() {
  cat <<EOF
Usage: $0 [options]

  -m, --machine   <name>       Machine output from flake
  -d, --disk      <device>     Target disk (e.g. /dev/nvme0n1)
  -f, --filesystem <btrfs|ext4>   (default: btrfs)
  -e, --encrypt                Enable LUKS2
  -E, --no-encrypt             Disable encryption
  -u, --user       <name>      Primary user (auto-detected if omitted)
  -r, --repo       <url>       Config repo (default: $REPO_URL_DEFAULT)
  -b, --branch     <branch>    Git branch (default: main)

Behaviour:
       --dry-run               Show steps, do nothing destructive
       --non-interactive       Require all mandatory flags, no prompts
       --yes                   Assume YES on confirmations
       --quiet | --debug
       --log-path <file>       Custom log location
       --no-color

  -h, --help      Show this help
  -v, --version   Print version
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
      *) echo "Unknown option $1"; usage; exit 1 ;;
    esac
  done

  [[ $SELECTED_FILESYSTEM =~ ^(btrfs|ext4)$ ]] || { echo "Unsupported filesystem"; exit 1; }
  [[ $SELECTED_FILESYSTEM == btrfs ]] || ENABLE_SNAPSHOTS=0

  if (( NON_INTERACTIVE )); then
    local miss=()
    [[ -z $SELECTED_MACHINE ]] && miss+=(--machine)
    [[ -z $SELECTED_DISK    ]] && miss+=(--disk)
    [[ -z $ENABLE_ENCRYPTION ]] && miss+=(--encrypt/--no-encrypt)
    (( ${#miss[@]} )) && { echo "Missing: ${miss[*]}"; exit 1; }
  fi
  export DRY_RUN NON_INTERACTIVE QUIET DEBUG
}

###############################################################################
# 3.  Error Handling
###############################################################################
cleanup_and_exit() {
  local code=${1:-0}
  [[ -n ${USER_OVERRIDE:-} && -f $USER_OVERRIDE ]] && rm -f "$USER_OVERRIDE"
  safe_unmount /mnt; cleanup_temp_files
  (( QUIET )) || echo -e "${GREEN}Done – log: $LOG_FILE${NC}"
  exit "$code"
}
trap 'log_error "line $LINENO -> $?"; cleanup_and_exit 1' ERR
trap 'cleanup_and_exit 130' INT TERM

###############################################################################
# 4.  Validation & deps
###############################################################################
validate_system() {
  print_step 1 11 "System validation"
  (( EUID == 0 )) && { echo "${RED}Run as normal user${NC}"; exit 1; }
  (( DRY_RUN )) || sudo -v
  [[ -f /etc/NIXOS ]] || confirm_action "Not a NixOS ISO – continue?" || exit 1
  check_network_connectivity || { echo "${RED}No network${NC}"; exit 1; }
  echo "${GREEN}✓ basic checks passed${NC}"
}

bootstrap_dependencies() {
  print_step 2 11 "Dependency bootstrap"
  local need=(git parted util-linux gptfdisk cryptsetup rsync tar jq bc)
  local miss=() bin
  for p in "${need[@]}"; do
    case $p in util-linux) bin=lsblk ;; gptfdisk) bin=sgdisk ;; *) bin=$p ;; esac
    command -v "$bin" &>/dev/null || miss+=("$p")
  done
  if (( ${#miss[@]} )); then
    exec nix-shell -p "${miss[@]}" --run "bash \"$0\" ${ORIGINAL_ARGS[*]}"
  fi
}

###############################################################################
# 5.  Repository + machine discovery
###############################################################################
setup_repository() {
  print_step 3 11 "Clone config repo"
  local dir=/tmp/nix-config; rm -rf "$dir"
  if (( DRY_RUN )); then
    mkdir -p "$dir/machines/example"; echo '{ }' > "$dir/machines/example/configuration.nix"
    cd "$dir"; return
  fi
  (git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$dir" &>/tmp/git_clone.log) &
  spinner $! "Cloning $REPO_URL"
  cd "$dir"
}

discover_machines() {
  print_step 4 11 "Discover machines"
  mapfile -t DISCOVERED_MACHINES < <(find machines -maxdepth 1 -mindepth 1 -type d ! -name templates -printf '%P\n')
  (( ${#DISCOVERED_MACHINES[@]} )) || { echo "No machine configs"; exit 1; }
}

###############################################################################
# 6.  Interactive selections (fs + machine + encryption + disk)
###############################################################################
select_machine() {
  print_step 5 11 "Machine selection"
  [[ -n $SELECTED_MACHINE ]] && return
  (( NON_INTERACTIVE )) && { echo "Machine required"; exit 1; }
  for i in "${!DISCOVERED_MACHINES[@]}"; do printf "  [%d] %s\n" $((i+1)) "${DISCOVERED_MACHINES[$i]}"; done
  read -rp "Select machine: " n
  SELECTED_MACHINE=${DISCOVERED_MACHINES[$((n-1))]}
}

select_filesystem() {
  print_step 6 11 "Filesystem"
  [[ -n $SELECTED_FILESYSTEM ]] && return
  (( NON_INTERACTIVE )) && return
  echo "  [1] Btrfs (snapshots)  [2] ext4"
  read -rp "Choice: " c
  [[ $c == 2 ]] && { SELECTED_FILESYSTEM=ext4; ENABLE_SNAPSHOTS=0; }
}

select_encryption() {
  print_step 7 11 "Encryption"
  [[ -n $ENABLE_ENCRYPTION ]] && return
  (( NON_INTERACTIVE )) && { echo "Encryption flag required"; exit 1; }
  read -rp "Enable LUKS2? [y/N]: " a
  ENABLE_ENCRYPTION=$([[ ${a,,} == y* ]] && echo 1 || echo 0)
}

list_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'; }
select_disk() {
  print_step 8 11 "Disk"
  [[ -n $SELECTED_DISK ]] && return
  (( NON_INTERACTIVE )) && { echo "Disk flag required"; exit 1; }
  mapfile -t dsks < <(list_disks)
  for i in "${!dsks[@]}"; do size=$(lsblk -bn -o SIZE "${dsks[$i]}"); printf "  [%d] %s %s\n" $((i+1)) "${dsks[$i]}" "$(printf '%dGiB' $((size/1024/1024/1024)))"; done
  read -rp "Select disk: " n
  SELECTED_DISK=${dsks[$((n-1))]}
  confirm_action "Erase ALL data on $SELECTED_DISK ?" || exit 1
}

###############################################################################
# 7.  Partition + filesystem
###############################################################################
run() { is_dry_run || "$@"; }

partition_disk() {
  print_step 9 11 "Partition disk"
  run sudo parted -s "$SELECTED_DISK" \
      mklabel gpt \
      mkpart ESP fat32 1MiB 512MiB set 1 esp on \
      mkpart primary 512MiB 100%
  run sudo partprobe "$SELECTED_DISK"; sleep 2
  run sudo mkfs.fat -F32 -n boot "${SELECTED_DISK}1"
}

root_partition() {
  lsblk -lnpo NAME "$SELECTED_DISK" | sort -V | sed -n '2p'
}

setup_btrfs() {
  local dev=$1
  run sudo mkfs.btrfs -f -L nixos "$dev"
  run sudo mount "$dev" /mnt
  for sv in @root @home @nix @snapshots; do run sudo btrfs subvolume create /mnt/$sv; done
  run sudo umount /mnt
  run sudo mount -o subvol=@root,compress=zstd "$dev" /mnt
  run sudo mkdir -p /mnt/{home,nix,.snapshots,boot}
  run sudo mount -o subvol=@home,compress=zstd "$dev" /mnt/home
  run sudo mount -o subvol=@nix,compress=zstd "$dev" /mnt/nix
  run sudo mount -o subvol=@snapshots,compress=zstd "$dev" /mnt/.snapshots
}

setup_filesystem() {
  print_step 10 11 "Create filesystem"
  local part=$(root_partition)
  if (( ENABLE_ENCRYPTION )); then
    run sudo cryptsetup -q luksFormat "$part" --type luks2
    run sudo cryptsetup open "$part" cryptroot
    part=/dev/mapper/cryptroot
  fi

  if [[ $SELECTED_FILESYSTEM == btrfs ]]; then
      setup_btrfs "$part"
  else
      run sudo mkfs.ext4 -F -L nixos "$part"
      run sudo mount "$part" /mnt
      run sudo mkdir -p /mnt/boot
  fi
  run sudo mount "${SELECTED_DISK}1" /mnt/boot
}

###############################################################################
# 8.  Build validation & install
###############################################################################
configure_user_override() {
  PRIMARY_USER=${PRIMARY_USER:-$(detect_primary_user_from_flake .)}
  validate_username "$PRIMARY_USER" || { echo "Bad username"; exit 1; }
  local def=$(detect_primary_user_from_flake .)
  if [[ $PRIMARY_USER != $def ]]; then
    echo "{ ... }: { mySystem.user = \"$PRIMARY_USER\"; }" > "machines/$SELECTED_MACHINE/_user-override.nix"
    USER_OVERRIDE="machines/$SELECTED_MACHINE/_user-override.nix"
  fi
}

dry_run_build() {
  nix $NIX_FLAGS build --dry-run ".#nixosConfigurations.$SELECTED_MACHINE.config.system.build.toplevel"
}

generate_hw_config() {
  print_step 11 11 "Generate hardware config"
  run sudo nixos-generate-config --root /mnt >/dev/null
}

install_nixos() {
  if is_dry_run; then
    echo "${YELLOW}[DRY-RUN] nixos-install skipped${NC}"
  else
    sudo nixos-install --no-root-password --flake ".#$SELECTED_MACHINE" --root /mnt
  fi
}

###############################################################################
# 9.  Main
###############################################################################
main() {
  parse_arguments "$@"
  (( QUIET )) || print_header "NixOS Installation Utility" "$SCRIPT_VERSION"

  validate_system
  bootstrap_dependencies
  setup_repository
  discover_machines

  select_machine; select_filesystem; select_encryption; select_disk

  configure_user_override
  dry_run_build

  partition_disk
  setup_filesystem
  generate_hw_config
  install_nixos

  [[ -n $USER_OVERRIDE && -f $USER_OVERRIDE && is_dry_run ]] && rm -f "$USER_OVERRIDE"
  cleanup_and_exit 0
}

main "$@"
