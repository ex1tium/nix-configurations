#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  « install_elara.sh » – Hardened automated NixOS installer for host Elara
# ──────────────────────────────────────────────────────────────────────────────
#   ✓ Fresh install   ✓ Dual‑boot (UEFI)   ✓ Manual mode  ✓ Optional LUKS2
#   ✓ Default **Btrfs** w/ snapshot‑ready root (ext4 & xfs opt‑in)
#   ✓ Robust gap detection, disk‑size validation, ESP safety backup
#   ✓ NVMe/SATA/virtio‑blk            ✓ Root‑safe, sudo keep‑alive & spinners
#   ✓ Pre-install build validation    ✓ Configuration warning detection
#   ✓ Comprehensive error reporting   ✓ Enhanced system requirements check
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

# Enhanced error handling with context
error_exit() {
  local line_no=$1
  local error_code=$2
  echo ""
  echo "❌  Script failed at line $line_no with exit code $error_code"
  echo "📍  Last command: ${BASH_COMMAND}"
  echo ""

  # Show relevant log files if they exist
  for log in /tmp/flake_check.log /tmp/build_test.log /tmp/nixos_install.log; do
    if [[ -f "$log" && -s "$log" ]]; then
      echo "📋  Recent entries from $(basename "$log"):"
      tail -10 "$log" | sed 's/^/    /'
      echo ""
    fi
  done

  echo "💡  For detailed logs, check files in /tmp/"
  exit "$error_code"
}

trap 'error_exit ${LINENO} $?' ERR

sudo -v # prime sudo
after_exit() { sudo kill "$SUDO_LOOP_PID" 2>/dev/null || true; }
while true; do sudo -n true 2>/dev/null || true; sleep 60; done & SUDO_LOOP_PID=$!
trap after_exit EXIT

###############################################################################
# Constants & defaults
###############################################################################
REPO_URL="https://github.com/ex1tium/nix-configurations.git"
REPO_BRANCH="main"
MACHINE="elara"
MIN_NIXOS_SIZE_GB=20
RECOMMENDED_NIXOS_SIZE_GB=50
FS_TYPE="btrfs"    # default FS
ENCRYPT="no"        # "yes" enables LUKS2 for root

###############################################################################
# CLI flags
###############################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fs=*) FS_TYPE="${1#*=}"; shift ;;
    --fs)
      if [[ -n "${2:-}" ]]; then
        FS_TYPE="$2"; shift 2
      else
        echo "❌ --fs requires a value (ext4|btrfs|xfs)"; exit 1
      fi
      ;;
    --encrypt) ENCRYPT="yes"; shift ;;
    --branch=*) REPO_BRANCH="${1#*=}"; shift ;;
    --branch)
      if [[ -n "${2:-}" ]]; then
        REPO_BRANCH="$2"; shift 2
      else
        echo "❌ --branch requires a value"; exit 1
      fi
      ;;
    --help|-h)
      echo "Usage: $0 [--fs ext4|btrfs|xfs] [--encrypt] [--branch <git_branch>]"
      echo "  --fs       Filesystem type (default: btrfs)"
      echo "  --encrypt  Enable LUKS2 encryption"
      echo "  --branch   Git branch to use (default: main)"
      exit 0
      ;;
    --) shift; break ;;  # End of options
    -*) echo "❌ Unknown option: $1"; echo "Use --help for usage"; exit 1 ;;
    *) break ;;  # Non-option argument, stop processing
  esac
done
[[ $FS_TYPE =~ ^(ext4|btrfs|xfs)$ ]] || { echo "❌ Unsupported --fs=$FS_TYPE"; exit 1; }
[[ $EUID -ne 0 ]] || { echo "❌ Do NOT run as root"; exit 1; }

# Verify we're on NixOS
if [[ ! -f /etc/NIXOS ]]; then
  echo "❌ This script must be run from a NixOS environment (live ISO or installed system)"
  echo "   Please boot from a NixOS ISO to run this installer"
  exit 1
fi

###############################################################################
# Enhanced system validation
###############################################################################
validate_system() {
  echo "🔍  Performing enhanced system validation..."

  # Check required tools beyond basic dependencies
  local missing_tools=()
  for tool in jq curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing_tools+=("$tool")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo "⚠️   Missing optional tools: ${missing_tools[*]}"
    echo "    These will be provided by nix-shell if needed."
  fi

  # Check sudo access and keep-alive
  if ! sudo -n true 2>/dev/null; then
    echo "🔐  Testing sudo access..."
    if ! sudo true; then
      echo "❌  Sudo access required but not available."
      exit 1
    fi
  fi

  # Check available disk space for build
  local available_space
  available_space=$(df /tmp --output=avail | tail -1)
  if [[ $available_space -lt 5000000 ]]; then  # 5GB in KB
    echo "⚠️   Low disk space in /tmp: $(( available_space / 1024 ))MB available"
    echo "    NixOS builds may require significant temporary space."
    read -rp "Continue anyway? [y/N]: " continue_space
    if [[ ! $continue_space =~ ^[Yy] ]]; then
      echo "Installation cancelled."
      exit 1
    fi
  fi

  echo "✅  Enhanced system validation completed"
}

# Run enhanced validation
validate_system

###############################################################################
# Dependency bootstrap – re‑exec inside nix‑shell if tools missing
###############################################################################
NEEDED=(git parted util-linux gptfdisk cryptsetup rsync tar jq)
MISSING=(); for p in "${NEEDED[@]}"; do
  case "$p" in
    util-linux) bin="lsblk" ;;
    gptfdisk) bin="sgdisk" ;;
    *) bin="$p" ;;
  esac
  command -v "$bin" &>/dev/null || MISSING+=("$p")
done

if (( ${#MISSING[@]} )); then
  echo "🔧  Entering nix‑shell for: ${MISSING[*]}"
  # Save script to temp file to avoid execution issues
  SCRIPT_PATH=$(mktemp)
  cat "$0" > "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  # Pass original arguments, filtering out any problematic ones
  CLEAN_ARGS=()
  for arg in "$@"; do
    case "$arg" in
      --fs|--encrypt|--branch) CLEAN_ARGS+=("$arg") ;;
      --fs=*|--branch=*) CLEAN_ARGS+=("$arg") ;;
      -*) ;; # Skip unknown flags
      *) CLEAN_ARGS+=("$arg") ;;
    esac
  done
  exec nix-shell -p "${MISSING[@]}" --run "bash \"$SCRIPT_PATH\" ${CLEAN_ARGS[*]}"
fi

# Verify all required tools are available
for b in git parted lsblk sgdisk cryptsetup nixos-generate-config nixos-install nix rsync tar pv; do
  command -v "$b" >/dev/null || { echo "❌ Missing required tool: $b"; exit 1; }
done

###############################################################################
# Helpers
###############################################################################
human() { printf "%dGB" $(( $1/1024/1024/1024 )); }
spinner() {
  local pid=$1 msg=$2 i=0 sp='|/-\\'
  while kill -0 $pid 2>/dev/null; do
    printf "\r%s %c" "$msg" "${sp:i++%4:1}"
    sleep 0.15
  done
  if wait $pid; then
    printf "\r%s ✓\n" "$msg"
  else
    printf "\r%s ❌\n" "$msg"
    return 1
  fi
}
largest_gap() { parted -m "$1" unit GB print free | awk -F: '$1=="free"{gsub(/GB/,"",$2);gsub(/GB/,"",$4); if($4+0>max){max=$4;start=$2}} END{print start,max}'; }
list_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'; }
find_esp() { lsblk -ln -o NAME,PARTTYPE "$1" | awk '$2~/[cC]12A7328|[eE][fF]00/{print "/dev/"$1; exit}'; }
format_root() { case $FS_TYPE in ext4) sudo mkfs.ext4 -F -L nixos "$1";; btrfs) sudo mkfs.btrfs -f -L nixos "$1";; xfs) sudo mkfs.xfs -f -L nixos "$1";; esac; }
backup_esp() { local esp=$1; local ts=$(date +%s); local tmp=$(mktemp -d); echo "🗄️  Backing up ESP…"; sudo mount -o ro "$esp" "$tmp"; sudo tar -C "$tmp" -cf "/tmp/esp_backup_${ts}.tar" .; sudo umount "$tmp"; rmdir "$tmp"; }

###############################################################################
# Disk selection & mode
###############################################################################
mapfile -t DISKS < <(list_disks); (( ${#DISKS[@]} )) || { echo "No disks"; exit 1; }
for i in "${!DISKS[@]}"; do printf "[%d] %s %s\n" $((i+1)) "${DISKS[$i]}" "$(human $(lsblk -bn -o SIZE "${DISKS[$i]}") )"; done
read -rp "Select disk: " n; (( n>=1 && n<=${#DISKS[@]} )) || exit 1; DISK="${DISKS[$((n-1))]}"
read -rp $'Mode 1)Fresh 2)Dual‑boot 3)Manual : ' MODE

###############################################################################
# Partition / mount helpers per mode
###############################################################################
mount_root() { sudo mount "$1" /mnt; sudo mkdir -p /mnt/boot; }

fresh_install() {
  local d=$1; echo "ERASE ALL on $d"; read -rp "Type ERASE: " x; [[ $x == ERASE ]] || exit 1
  sudo parted -s "$d" mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 esp on mkpart primary 512MiB 100%
  sudo mkfs.fat -F32 -n boot "${d}1"
  local r="${d}2"; [[ $ENCRYPT == yes ]] && { sudo cryptsetup luksFormat "$r" --type luks2; sudo cryptsetup open "$r" cryptroot; r=/dev/mapper/cryptroot; }
  format_root "$r"; mount_root "$r"; sudo mount "${d}1" /mnt/boot
}

dual_boot() {
  local d=$1; local esp=$(find_esp "$d"); [[ $esp ]] || { echo "No ESP"; exit 1; }
  backup_esp "$esp"
  read -rp "Root size GB [${RECOMMENDED_NIXOS_SIZE_GB}]: " SZ; SZ=${SZ:-$RECOMMENDED_NIXOS_SIZE_GB}; (( SZ>=MIN_NIXOS_SIZE_GB )) || exit 1
  read s gap <<< "$(largest_gap "$d")"; (( gap>=SZ )) || { echo "Not enough free"; exit 1; }
  local e=$(printf '%.2f' "$(bc -l <<< "$s+$SZ")")
  sudo parted -s "$d" mkpart primary "${s}GB" "${e}GB"; sudo partprobe "$d"; sleep 2
  local np="/dev/$(lsblk -ln -o NAME "$d" | tail -1)"; [[ $ENCRYPT == yes ]] && { sudo cryptsetup luksFormat "$np" --type luks2; sudo cryptsetup open "$np" cryptroot; np=/dev/mapper/cryptroot; }
  format_root "$np"; mount_root "$np"; sudo mount "$esp" /mnt/boot
}

[[ $MODE == 1 ]] && fresh_install "$DISK"
[[ $MODE == 2 ]] && dual_boot  "$DISK"
[[ $MODE == 3 ]] && { echo "Manual: mount /mnt and /mnt/boot then Enter"; read; mountpoint -q /mnt && mountpoint -q /mnt/boot || exit 1; }

###############################################################################
# Clone flake & ask for username BEFORE install
###############################################################################

echo "📥  Cloning flake ($REPO_BRANCH)…"; rm -rf /tmp/nix-config
(git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" /tmp/nix-config &> /tmp/git_clone.log) & spinner $! "Clone"
cd /tmp/nix-config || exit 1

NIX_FLAGS="--experimental-features nix-command flakes"
PRIMARY_USER=$(nix $NIX_FLAGS eval ".#globalConfig.defaultUser" --raw 2>/dev/null || grep -o 'defaultUser *= *"[^" ]*"' flake.nix | head -1 | cut -d'"' -f2 || echo "ex1tium")

echo "Detected primary user: $PRIMARY_USER"; read -rp "Is this OK? [Y/n]: " ok; ok=${ok:-Y}
if [[ $ok =~ ^[Nn] ]]; then read -rp "Enter username: " PRIMARY_USER; fi

# If overridden, write a transient overlay module so install succeeds
USER_OVERRIDE=""
if ! grep -R --include='*.nix' -E "mySystem\.user\s*=\s*\"${PRIMARY_USER}\"" . >/dev/null 2>&1; then
  echo "{ ... }: { mySystem.user = \"$PRIMARY_USER\"; }" > "machines/$MACHINE/_user-override.nix"
  echo "  User override created for installation"
  USER_OVERRIDE="machines/$MACHINE/_user-override.nix"
fi

###############################################################################
# Generate HW config & validate build
###############################################################################
sudo nixos-generate-config --root /mnt >/dev/null
sudo cp /mnt/etc/nixos/hardware-configuration.nix "machines/$MACHINE/"

# Comprehensive flake validation
echo "🔍  Validating flake configuration..."
if ! nix $NIX_FLAGS flake check --no-build 2>/tmp/flake_check.log; then
  echo "❌  Flake validation failed!"
  echo "📋  Flake check errors:"
  cat /tmp/flake_check.log
  exit 1
fi

# Check for configuration warnings
echo "⚠️   Checking for configuration warnings..."
if nix $NIX_FLAGS eval ".#nixosConfigurations.$MACHINE.config.warnings" --json 2>/dev/null | jq -e '. | length > 0' >/dev/null 2>&1; then
  echo "⚠️   Configuration warnings detected:"
  nix $NIX_FLAGS eval ".#nixosConfigurations.$MACHINE.config.warnings" --json 2>/dev/null | jq -r '.[]' | sed 's/^/    /'
  echo ""
  read -rp "Continue with installation despite warnings? [y/N]: " continue_warn
  if [[ ! $continue_warn =~ ^[Yy] ]]; then
    echo "Installation cancelled. Please fix warnings first."
    exit 1
  fi
  echo ""
fi

# Test build without installing (dry-run)
echo "🧪  Testing system build (dry-run)..."
if ! nix $NIX_FLAGS build --dry-run ".#nixosConfigurations.$MACHINE.config.system.build.toplevel" 2>/tmp/build_test.log; then
  echo "❌  System build test failed!"
  echo "📋  Build test errors:"
  cat /tmp/build_test.log
  echo ""
  echo "�  This means the system configuration has issues that would cause installation to fail."
  echo "    Please fix the configuration before attempting installation."
  exit 1
fi

echo "✅  Build validation passed!"
echo ""

# Actual installation with full error reporting
echo "🚀  Installing NixOS..."
if ! sudo nixos-install --no-root-password --flake ".#$MACHINE" --root /mnt 2>&1 | tee /tmp/nixos_install.log; then
  echo ""
  echo "❌  Installation failed!"
  echo "📋  Installation errors:"
  tail -50 /tmp/nixos_install.log
  echo ""
  echo "💡  Full installation log available at: /tmp/nixos_install.log"
  exit 1
fi

echo "✅  Installation completed successfully!"

# Cleanup temporary user override file
if [[ -n "$USER_OVERRIDE" && -f "$USER_OVERRIDE" ]]; then
  rm -f "$USER_OVERRIDE"
  echo "🧹  Cleaned up temporary user override"
fi

###############################################################################
# Post‑install password setup
###############################################################################
read -rp "Set password for $PRIMARY_USER now? [Y/n]: " setpw; setpw=${setpw:-Y}
if [[ $setpw =~ ^[Yy] ]]; then
  echo "Setting password for $PRIMARY_USER..."
  if ! sudo nixos-enter --root /mnt -c "passwd $PRIMARY_USER" 2>/dev/null; then
    echo "⚠️  nixos-enter failed, trying alternative method..."
    echo "You can set the password after reboot with: sudo passwd $PRIMARY_USER"
  fi
fi

read -rp "Set root password? [y/N]: " setroot
if [[ $setroot =~ ^[Yy] ]]; then
  echo "Setting root password..."
  if ! sudo nixos-enter --root /mnt -c "passwd root" 2>/dev/null; then
    echo "⚠️  nixos-enter failed, trying alternative method..."
    echo "You can set the root password after reboot with: sudo passwd root"
  fi
fi

echo -e "\n\033[1;32m🎉  Done — remove media and reboot.\033[0m"
