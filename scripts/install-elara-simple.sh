#!/usr/bin/env bash
# Simple NixOS installer for Elara (no CLI arguments)
# This version avoids argument parsing issues

set -Eeuo pipefail
IFS=$'\n\t'

trap 'echo -e "\033[1;31m❌  Error at line $LINENO – aborting.\033[0m" >&2' ERR

# Constants
REPO_URL="https://github.com/ex1tium/nix-configurations.git"
REPO_BRANCH="main"
MACHINE="elara"
MIN_NIXOS_SIZE_GB=20
RECOMMENDED_NIXOS_SIZE_GB=50
FS_TYPE="btrfs"
ENCRYPT="no"

# Basic checks
[[ $EUID -ne 0 ]] || { echo "❌ Do NOT run as root"; exit 1; }
[[ -f /etc/NIXOS ]] || { echo "❌ Must run from NixOS environment"; exit 1; }

# Sudo setup
sudo -v
while true; do sudo -n true 2>/dev/null || true; sleep 60; done & SUDO_LOOP_PID=$!
cleanup() { sudo kill $SUDO_LOOP_PID 2>/dev/null || true; }
trap cleanup EXIT

# Install missing tools
NEEDED=(git parted util-linux gptfdisk cryptsetup rsync tar pv)
MISSING=()
for p in "${NEEDED[@]}"; do 
  case "$p" in
    util-linux) bin="lsblk" ;;
    gptfdisk) bin="sgdisk" ;;
    *) bin="$p" ;;
  esac
  command -v "$bin" &>/dev/null || MISSING+=("$p")
done

if (( ${#MISSING[@]} )); then
  echo "🔧 Installing missing tools: ${MISSING[*]}"
  nix-shell -p "${MISSING[@]}" --run "exec bash $0"
  exit 0
fi

# Helper functions
human() { printf "%dGB" $(( $1/1024/1024/1024 )); }
spinner() { local pid=$1 msg=$2 i=0 sp='|/-\\'; while kill -0 $pid 2>/dev/null; do printf "\r%s %c" "$msg" "${sp:i++%4:1}"; sleep 0.15; done; printf "\r%s ✓\n" "$msg"; }
largest_gap() { parted -m "$1" unit GB print free | awk -F: '$1=="free"{gsub(/GB/,"",$2);gsub(/GB/,"",$4); if($4+0>max){max=$4;start=$2}} END{print start,max}'; }
list_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'; }
find_esp() { lsblk -ln -o NAME,PARTTYPE "$1" | awk '$2~/[cC]12A7328|[eE][fF]00/{print "/dev/"$1; exit}'; }
format_root() { case $FS_TYPE in ext4) sudo mkfs.ext4 -F -L nixos "$1";; btrfs) sudo mkfs.btrfs -f -L nixos "$1";; xfs) sudo mkfs.xfs -f -L nixos "$1";; esac; }
backup_esp() { local esp=$1 ts=$(date +%s) tmp=$(mktemp -d); echo "🗄️ Backing up ESP…"; sudo mount -o ro "$esp" "$tmp"; sudo tar -C "$tmp" -cf "/tmp/esp_backup_${ts}.tar" .; sudo umount "$tmp"; rmdir "$tmp"; }

# Disk selection
mapfile -t DISKS < <(list_disks); (( ${#DISKS[@]} )) || { echo "No disks"; exit 1; }
echo "🔍 Detected disks:"
for i in "${!DISKS[@]}"; do printf "[%d] %s %s\n" $((i+1)) "${DISKS[$i]}" "$(human $(lsblk -bn -o SIZE "${DISKS[$i]}") )"; done
read -rp "Select disk: " n; (( n>=1 && n<=${#DISKS[@]} )) || exit 1; DISK="${DISKS[$((n-1))]}"
read -rp $'Mode 1)Fresh 2)Dual‑boot 3)Manual : ' MODE

# Mount function
mount_root() { sudo mount "$1" /mnt; sudo mkdir -p /mnt/boot; }

# Installation modes
if [[ $MODE == 1 ]]; then
  echo "⚠️ ERASE ALL on $DISK"; read -rp "Type ERASE: " x; [[ $x == ERASE ]] || exit 1
  sudo parted -s "$DISK" mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 esp on mkpart primary 512MiB 100%
  sudo mkfs.fat -F32 -n boot "${DISK}1"
  local r="${DISK}2"; [[ $ENCRYPT == yes ]] && { sudo cryptsetup luksFormat "$r" --type luks2; sudo cryptsetup open "$r" cryptroot; r=/dev/mapper/cryptroot; }
  format_root "$r"; mount_root "$r"; sudo mount "${DISK}1" /mnt/boot
elif [[ $MODE == 2 ]]; then
  local esp=$(find_esp "$DISK"); [[ $esp ]] || { echo "No ESP"; exit 1; }
  backup_esp "$esp"
  read -rp "Root size GB [${RECOMMENDED_NIXOS_SIZE_GB}]: " SZ; SZ=${SZ:-$RECOMMENDED_NIXOS_SIZE_GB}; (( SZ>=MIN_NIXOS_SIZE_GB )) || exit 1
  read s gap <<< "$(largest_gap "$DISK")"; (( gap>=SZ )) || { echo "Not enough free"; exit 1; }
  local e=$(printf '%.2f' "$(bc -l <<< "$s+$SZ")")
  sudo parted -s "$DISK" mkpart primary "${s}GB" "${e}GB"; sudo partprobe "$DISK"; sleep 2
  local np="/dev/$(lsblk -ln -o NAME "$DISK" | tail -1)"; [[ $ENCRYPT == yes ]] && { sudo cryptsetup luksFormat "$np" --type luks2; sudo cryptsetup open "$np" cryptroot; np=/dev/mapper/cryptroot; }
  format_root "$np"; mount_root "$np"; sudo mount "$esp" /mnt/boot
elif [[ $MODE == 3 ]]; then
  echo "Manual: mount /mnt and /mnt/boot then Enter"; read; mountpoint -q /mnt && mountpoint -q /mnt/boot || exit 1
else
  echo "Invalid mode"; exit 1
fi

# Clone and install
echo "📥 Cloning flake ($REPO_BRANCH)…"; rm -rf /tmp/nix-config
(git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" /tmp/nix-config &> /tmp/git_clone.log) & spinner $! "Clone"
cd /tmp/nix-config || exit 1

NIX_FLAGS="--experimental-features nix-command flakes"
PRIMARY_USER=$(nix $NIX_FLAGS eval ".#globalConfig.defaultUser" --raw 2>/dev/null || grep -o 'defaultUser *= *"[^" ]*"' flake.nix | head -1 | cut -d'"' -f2 || echo "ex1tium")

echo "Detected primary user: $PRIMARY_USER"; read -rp "Is this OK? [Y/n]: " ok; ok=${ok:-Y}
if [[ $ok =~ ^[Nn] ]]; then read -rp "Enter username: " PRIMARY_USER; fi

if ! grep -q "${PRIMARY_USER}" flake.nix; then
  echo "{ ... }: { mySystem.user = \"$PRIMARY_USER\"; }" > "machines/$MACHINE/_user-override.nix"
fi

sudo nixos-generate-config --root /mnt >/dev/null
sudo cp /mnt/etc/nixos/hardware-configuration.nix "machines/$MACHINE/"

(nix $NIX_FLAGS flake check --no-build &>/tmp/flake_check.log || true) & spinner $! "Flake check"

echo "🚀 nixos-install…"; (sudo nixos-install --no-root-password --flake ".#$MACHINE" --root /mnt &>/tmp/nixos_install.log) & spinner $! "Install"

read -rp "Set password for $PRIMARY_USER now? [Y/n]: " setpw; setpw=${setpw:-Y}
[[ $setpw =~ ^[Yy] ]] && sudo chroot /mnt passwd "$PRIMARY_USER"
read -rp "Set root password? [y/N]: " setroot; [[ $setroot =~ ^[Yy] ]] && sudo chroot /mnt passwd root

echo -e "\n\033[1;32m🎉 Done — remove media and reboot.\033[0m"
