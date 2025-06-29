#!/usr/bin/env -S bash -Eeuo pipefail
# « install-elara.sh » – fully-automated installer for the Elara host
# ------------------------------------------------------------
#  ▸ Fresh / dual-boot / manual
#  ▸ Optional LUKS2
#  ▸ Btrfs sub-volume layout by default
#  ▸ Re-uses lib/common.sh for all helpers
# ------------------------------------------------------------

shopt -s inherit_errexit lastpipe
IFS=$'\n\t'

########################################################################
# 0.  Shared library
########################################################################
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
LOG_FILE="/tmp/elara-install-$(date +%Y%m%d-%H%M%S).log"
export LOG_FILE
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

########################################################################
# 1.  Constants / defaults
########################################################################
readonly MACHINE="elara"
readonly REPO_URL_DEFAULT="https://github.com/ex1tium/nix-configurations.git"
readonly MIN_NIXOS_SIZE_GB=20
readonly RECOMMENDED_NIXOS_SIZE_GB=50

REPO_URL=$REPO_URL_DEFAULT
REPO_BRANCH="main"
FS_TYPE="btrfs"
ENABLE_ENCRYPTION=0          # 1 = yes, 0 = no
DRY_RUN=0                    # inherits --dry-run from common, but we keep a local flag for crypt/layout calls

########################################################################
# 2.  CLI
########################################################################
usage() {
  cat <<EOF
Usage: $0 [--fs ext4|btrfs|xfs] [--encrypt] [--branch <git_branch>] [--dry-run]

Options:
  --fs         Filesystem type (default: btrfs)
  --encrypt    Enable LUKS2 on root
  --branch     Git branch to clone (default: main)
  --dry-run    Show actions, do nothing destructive
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --fs)       FS_TYPE=$2; shift 2 ;;
    --fs=*)     FS_TYPE=${1#*=}; shift ;;
    --encrypt)  ENABLE_ENCRYPTION=1; shift ;;
    --branch)   REPO_BRANCH=$2; shift 2 ;;
    --branch=*) REPO_BRANCH=${1#*=}; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    -v|--version) echo "install-elara 2.0.0"; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
[[ $FS_TYPE =~ ^(btrfs|ext4|xfs)$ ]] || { echo "Unsupported --fs=$FS_TYPE"; exit 1; }

########################################################################
# 3.  Validation & deps
########################################################################
validate_system() {
  print_step 1 6 "System validation (Elara)"
  (( EUID == 0 )) && { echo "${RED}Run as normal user${NC}"; exit 1; }
  (( DRY_RUN )) || sudo -v
  [[ -f /etc/NIXOS ]] || { echo "${RED}Not a NixOS environment${NC}"; exit 1; }
  check_network_connectivity || { echo "${RED}No network${NC}"; exit 1; }
  echo "${GREEN}✓ host OK${NC}"
}
bootstrap_dependencies() {
  print_step 2 6 "Dependency bootstrap"
  local need=(git parted util-linux gptfdisk cryptsetup rsync tar jq bc)
  local miss=() bin
  for p in "${need[@]}"; do
    case $p in util-linux) bin=lsblk ;; gptfdisk) bin=sgdisk ;; *) bin=$p ;; esac
    command -v "$bin" &>/dev/null || miss+=("$p")
  done
  if (( ${#miss[@]} )); then
    log_info "Entering nix-shell for: ${miss[*]}"
    exec nix-shell -p "${miss[@]}" --run "bash \"$0\" \"$@\""
  fi
}

########################################################################
# 4.  Disk helpers  (all destructive calls guarded by DRY_RUN)
########################################################################
list_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'; }
human()       { printf "%dGiB" "$(( $1/1024/1024/1024 ))"; }

run() { is_dry_run || "$@"; }       # wrapper uses common.sh's is_dry_run

partition_fresh() {
  local disk=$1
  run sudo parted -s "$disk" mklabel gpt          \
       mkpart ESP fat32 1MiB 512MiB set 1 esp on  \
       mkpart primary 512MiB 100%
  run sudo mkfs.fat -F32 -n boot "${disk}1"
}

create_btrfs_subvols() {
  local dev=$1
  run sudo mkfs.btrfs -f -L nixos "$dev"
  run sudo mount "$dev" /mnt
  for sv in @root @home @nix @snapshots; do run sudo btrfs subvolume create /mnt/$sv; done
  run sudo umount /mnt
  run sudo mount -o subvol=@root,compress=zstd "$dev" /mnt
  run sudo mkdir -p /mnt/{home,nix,.snapshots,boot}
  run sudo mount -o subvol=@home,compress=zstd "$dev" /mnt/home
  run sudo mount -o subvol=@nix,compress=zstd  "$dev" /mnt/nix
  run sudo mount -o subvol=@snapshots,compress=zstd "$dev" /mnt/.snapshots
}

setup_root_fs() {
  local part=$1
  if (( ENABLE_ENCRYPTION )); then
     run sudo cryptsetup -q luksFormat "$part" --type luks2
     run sudo cryptsetup open "$part" cryptroot
     part=/dev/mapper/cryptroot
  fi

  if [[ $FS_TYPE == btrfs ]]; then
    create_btrfs_subvols "$part"
  else
    [[ $FS_TYPE == ext4 ]] && run sudo mkfs.ext4 -F -L nixos "$part"
    [[ $FS_TYPE == xfs  ]] && run sudo mkfs.xfs  -f -L nixos "$part"
    run sudo mount "$part" /mnt
    run sudo mkdir -p /mnt/boot
  fi
}

########################################################################
# 5.  Workflow
########################################################################
main() {
  print_header "Elara installer" "2.0.0"
  validate_system
  bootstrap_dependencies

  print_step 3 6 "Disk selection"
  mapfile -t DISKS < <(list_disks)
  for i in "${!DISKS[@]}"; do
    printf "[%d] %s %s\n" $((i+1)) "${DISKS[$i]}" "$(human "$(lsblk -bn -o SIZE "${DISKS[$i]}")")"
  done
  read -rp "Select disk: " n
  DISK=${DISKS[$((n-1))]}

  read -rp $'Mode (1=fresh, 2=dual-boot, 3=manual): ' MODE
  case $MODE in
    1) confirm_action "Erase ALL data on $DISK ?" || exit 1
       partition_fresh "$DISK"
       setup_root_fs "${DISK}2"
       run sudo mount "${DISK}1" /mnt/boot ;;
    2) echo "${RED}Dual-boot flow not implemented in this minimalist demo${NC}"; exit 1 ;;
    3) echo "Manual: mount root at /mnt & ESP at /mnt/boot and press Enter"; read ;;
    *) exit 1 ;;
  esac

  print_step 4 6 "Clone flake"
  run rm -rf /tmp/nix-config
  (git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" /tmp/nix-config &>/tmp/git_clone.log) &
  spinner $! "Cloning $REPO_URL"
  cd /tmp/nix-config

  print_step 5 6 "User detection"
  PRIMARY_USER=$(detect_primary_user_from_flake .)
  confirm_action "Use '$PRIMARY_USER' as primary user?" y || read -rp "Enter user: " PRIMARY_USER

  [[ -f machines/$MACHINE/_user-override.nix ]] && run rm -f machines/$MACHINE/_user-override.nix
  echo "{ ... }: { mySystem.user = \"$PRIMARY_USER\"; }" > machines/$MACHINE/_user-override.nix
  USER_OVERRIDE=machines/$MACHINE/_user-override.nix

  print_step 6 6 "Install (dry-run build test)"
  if ! run nix $NIX_FLAGS build --dry-run ".#nixosConfigurations.$MACHINE.config.system.build.toplevel"; then
     echo "${RED}Build failed${NC}"; exit 1
  fi
  echo "${GREEN}✓ build looks good${NC}"

  if is_dry_run; then
     echo "${YELLOW}[DRY-RUN] stop before nixos-install${NC}"
  else
     run sudo nixos-install --no-root-password --flake ".#$MACHINE" --root /mnt
     echo -e "\n${GREEN}🎉 Elara installed. Remove media & reboot.${NC}"
  fi

  [[ -f $USER_OVERRIDE ]] && run rm -f "$USER_OVERRIDE"
  cleanup_and_exit 0
}

main "$@"
