#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  « install_elara.sh » – Hardened automated NixOS installer for host Elara
# ──────────────────────────────────────────────────────────────────────────────
#   ✓ Fresh install   ✓ Dual‑boot (UEFI)   ✓ Manual mode  ✓ Optional LUKS2
#   ✓ Default **Btrfs** w/ snapshot‑ready root (ext4 & xfs opt‑in)
#   ✓ Robust gap detection, disk‑size validation, ESP safety backup
#   ✓ NVMe/SATA/virtio‑blk            ✓ Root‑safe, sudo keep‑alive & spinners
#
#   USAGE (from official NixOS ISO):
#     $ ./install_elara.sh [--fs ext4|btrfs|xfs] [--encrypt] [--branch <git_branch>]
#
#   Execute as a normal user with sudo privileges.
# ──────────────────────────────────────────────────────────────────────────────

set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# Error handling & sudo keep‑alive
###############################################################################
trap 'echo -e "\033[1;31m❌  Error at line $LINENO – aborting.\033[0m" >&2' ERR

sudo -v                                         # prime sudo
while true; do sudo -n true 2>/dev/null || true; sleep 60; done &
SUDO_LOOP_PID=$!
cleanup() { sudo kill $SUDO_LOOP_PID 2>/dev/null || true; }
trap cleanup EXIT

###############################################################################
# Constants & defaults
###############################################################################
REPO_URL="https://github.com/ex1tium/nix-configurations.git"
REPO_BRANCH="main"
MACHINE="elara"
MIN_NIXOS_SIZE_GB=20
RECOMMENDED_NIXOS_SIZE_GB=50
FS_TYPE="btrfs"    # default is Btrfs now (snapshot‑friendly)
ENCRYPT="no"        # yes ⇒ LUKS2 on root

###############################################################################
# CLI flags
###############################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fs)      FS_TYPE="$2"; shift 2 ;;
    --encrypt) ENCRYPT="yes"; shift ;;
    --branch)  REPO_BRANCH="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

[[ $FS_TYPE =~ ^(ext4|btrfs|xfs)$ ]] || { echo "Unsupported --fs=$FS_TYPE"; exit 1; }

###############################################################################
# Root guard
###############################################################################
[[ $EUID -ne 0 ]] || { echo "❌  Do NOT run as root"; exit 1; }

###############################################################################
# Dependency check (auto nix‑shell)
###############################################################################
NEEDED=(git parted util-linux/sbin/lsblk gptfdisk/sgdisk cryptsetup rsync tar pv)
MISSING=()
for pkg in "${NEEDED[@]}"; do cmd=${pkg##*/}; command -v "$cmd" &>/dev/null || MISSING+=("$pkg"); done
if (( ${#MISSING[@]} )); then
  echo "🔧  Launching nix‑shell for missing tools: ${MISSING[*]#*/}"
  exec nix-shell -p "${MISSING[@]}" --run "bash \"$0\" \"$@\""
fi

for b in git parted lsblk sgdisk cryptsetup nixos-generate-config nixos-install nix rsync tar pv; do command -v "$b" &>/dev/null || { echo "Missing $b"; exit 1; }; done

###############################################################################
# Helper functions
###############################################################################
human() { printf "%dGB" $(( $1 / 1024 / 1024 / 1024 )); }

spinner() { # $1=pid  $2=msg
  local pid=$1 msg=$2 i=0 sp='|/-\\'
  while kill -0 $pid 2>/dev/null; do printf "\r%s %c" "$msg" "${sp:i++%${#sp}:1}"; sleep 0.15; done
  printf "\r%s ✓\n" "$msg"
}

largest_free_segment() { # echo start size
  parted -m "$1" unit GB print free | awk -F: '$1=="free"{gsub(/GB/,"",$2);gsub(/GB/,"",$4); if($4+0>max){max=$4;start=$2}} END{print start,max}'
}

list_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'; }

find_esp() {
  lsblk -ln -o NAME,PARTTYPE "$1" | awk '$2 ~ /(c12a7328|C12A7328|ef00|EF00)/{print "/dev/"$1; exit}'
}

format_root_fs() {
  case "$FS_TYPE" in
    ext4) sudo mkfs.ext4 -F -L nixos "$1" ;;
    btrfs) sudo mkfs.btrfs -f -L nixos "$1" ;;
    xfs)   sudo mkfs.xfs   -f -L nixos "$1" ;;
  esac
}

mount_root() { sudo mount "$1" /mnt; sudo mkdir -p /mnt/boot; }

backup_esp() { # paranoid ESP backup to /tmp/esp_backup_<ts>.tar
  local esp="$1" ts=$(date +%s) tmpdir; tmpdir=$(mktemp -d)
  echo "🗄️   Backing up ESP to /tmp/esp_backup_${ts}.tar (read‑only)…"
  sudo mount -o ro "$esp" "$tmpdir"
  sudo tar -C "$tmpdir" -cf "/tmp/esp_backup_${ts}.tar" .
  sudo umount "$tmpdir"; rmdir "$tmpdir"
}

###############################################################################
# Disk selection UI
###############################################################################
mapfile -t DISKS < <(list_disks)
(( ${#DISKS[@]} )) || { echo "No disks detected"; exit 1; }

echo "🔍  Detected disks:"; for i in "${!DISKS[@]}"; do d="${DISKS[$i]}"; echo " [$((i+1))] $d  $(human $(lsblk -bn -o SIZE "$d"))"; done
read -rp "Choose disk number: " idx
(( idx>=1 && idx<=${#DISKS[@]} )) || { echo "Invalid choice"; exit 1; }
DISK="${DISKS[$((idx-1))]}"; echo "✅  Using $DISK"

read -rp $'Install mode: 1) Fresh  2) Dual‑boot  3) Manual : ' MODE

###############################################################################
# Install modes
###############################################################################
fresh_install() {
  local d="$1"
  echo "⚠️  This will ERASE ALL data on $d"; read -rp "Type ERASE to continue: " c; [[ $c == ERASE ]] || exit 1

  sudo parted -s "$d" mklabel gpt
  sudo parted -s "$d" mkpart ESP fat32 1MiB 512MiB set 1 esp on
  sudo parted -s "$d" mkpart primary 512MiB 100%

  sudo mkfs.fat -F32 -n boot "${d}1"
  local rootdev="${d}2"
  if [[ $ENCRYPT == yes ]]; then sudo cryptsetup luksFormat "$rootdev" --type luks2 && sudo cryptsetup open "$rootdev" cryptroot && rootdev=/dev/mapper/cryptroot; fi

  format_root_fs "$rootdev"
  mount_root "$rootdev"
  sudo mount "${d}1" /mnt/boot
}

dual_boot() {
  local d="$1" esp
  esp=$(find_esp "$d") || true; [[ $esp ]] || { echo "No ESP on $d"; exit 1; }
  echo "✅  ESP: $esp"
  backup_esp "$esp"

  read -rp "Root size in GB [${RECOMMENDED_NIXOS_SIZE_GB}]: " SZ; SZ=${SZ:-$RECOMMENDED_NIXOS_SIZE_GB}
  (( SZ >= MIN_NIXOS_SIZE_GB )) || { echo "Too small"; exit 1; }

  read start size <<< "$(largest_free_segment "$d")"; (( size >= SZ )) || { echo "Largest free gap ${size}GB < requested $SZ"; exit 1; }
  end=$(printf '%.2f' "$(bc -l <<< "$start + $SZ")")

  total=$(lsblk -bn -o SIZE "$d"); totalGB=$(( total / 1024 / 1024 / 1024 ))
  (( end <= totalGB )) || { echo "Partition would exceed disk size"; exit 1; }

  echo "🔧  Creating ${SZ}GB partition at ${start}-${end}GB…"; sudo parted -s "$d" mkpart primary "${start}GB" "${end}GB"; sudo partprobe "$d"; sleep 2
  newpart="/dev/$(lsblk -ln -o NAME "$d" | tail -1)"

  [[ $ENCRYPT == yes ]] && { sudo cryptsetup luksFormat "$newpart" --type luks2; sudo cryptsetup open "$newpart" cryptroot; newpart=/dev/mapper/cryptroot; }

  format_root_fs "$newpart"; mount_root "$newpart"; sudo mount "$esp" /mnt/boot
}

manual_mode() { echo "→ Manual mode: mount root at /mnt and ESP at /mnt/boot, then press Enter"; read; mountpoint -q /mnt && mountpoint -q /mnt/boot || { echo "Required mounts missing"; exit 1; }; }

case $MODE in 1) fresh_install "$DISK" ;; 2) dual_boot "$DISK" ;; 3) manual_mode ;; *) echo "Invalid mode"; exit 1;; esac

###############################################################################
# NixOS installation with progress spinner
###############################################################################

echo "📥  Cloning flake (branch $REPO_BRANCH)…"
rm -rf /tmp/nix-config 2>/dev/null || true
(git clone --depth 1 --branch "$REPO_BRANCH" --progress "$REPO_URL" /tmp/nix-config &> /tmp/git_clone.log) &
spinner $! "Cloning flake"
[[ -f /tmp/nix-config/flake.nix ]] || { echo "Flake clone failed"; cat /tmp/git_clone.log; exit 1; }

cd /tmp/nix-config
NIX_FLAGS="--experimental-features nix-command flakes"
(nix $NIX_FLAGS flake check --no-build &> /tmp/flake_check.log || true) & spinner $! "Flake check"

sudo nixos-generate-config --root /mnt > /dev/null
sudo cp /mnt/etc/nixos/hardware-configuration.nix "machines/$MACHINE/"

echo "🚀  Running nixos-install…"
(sudo nixos-install --no-root-password --flake ".#$MACHINE" --root /mnt &> /tmp/nixos_install.log) &
spinner $! "nixos-install"
if ! tail -1 /tmp/nixos_install.log | grep -q "done"; then echo "Install failed"; cat /tmp/nixos_install.log; exit 1; fi

echo -e "\n\033[1;32m🎉  Installation complete – reboot when ready!\033[0m"
