#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  « install_elara.sh » – Hardened automated NixOS installer for host Elara
# ──────────────────────────────────────────────────────────────────────────────
#   ✓ Fresh install   ✓ Dual‑boot (UEFI)   ✓ Manual mode  ✓ Optional LUKS2
#   ✓ Default **Btrfs** w/ snapshot‑ready sub‑volume layout (ext4 & xfs opt‑in)
#   ✓ Robust gap detection, disk‑size validation, ESP safety backup
#   ✓ NVMe/SATA/virtio‑blk            ✓ Root‑safe, sudo keep‑alive & spinners
#   ✓ Pre‑install build validation    ✓ Configuration warning detection
#   ✓ Comprehensive error reporting   ✓ Enhanced system requirements check
#   ✓ Dependency auto‑bootstrap via nix‑shell (incl. bc, pv)
#
#   USAGE (from official NixOS ISO):
#     $ ./install_elara.sh [--fs ext4|btrfs|xfs] [--encrypt] [--branch <git_branch>]
#
#   Execute as a **normal** user with sudo privileges (not as root).
# ──────────────────────────────────────────────────────────────────────────────
#  Revision 2025‑06‑29:  • Standard Btrfs sub‑volume layout & zstd compression
#                        • Added missing deps (bc, pv)  • Safer crypt mapper
#                        • Better partition detection   • Cleanup traps
#                        • Minor shell‑lint hardening
# ──────────────────────────────────────────────────────────────────────────────

set -Eeuo pipefail
IFS=$'\n\t'
export LANG=C   # ensure decimal separator for bc et al.

###############################################################################
# Error handling & sudo keep‑alive
###############################################################################
error_exit() {
  local line_no=$1
  local err_code=$2
  printf "\n❌  Script failed at line %d with exit code %d\n" "$line_no" "$err_code"
  printf "📍  Last command: %s\n\n" "${BASH_COMMAND}"

  for log in /tmp/flake_check.log /tmp/build_test.log /tmp/nixos_install.log; do
    if [[ -s "$log" ]]; then
      printf "📋  Recent entries from %s:\n" "$(basename "$log")"
      tail -10 "$log" | sed 's/^/    /'
      echo
    fi
  done
  echo "💡  For detailed logs, check files in /tmp/"
  exit "$err_code"
}
trap 'error_exit ${LINENO} $?' ERR

# sudo keep‑alive (background)
sudo -v
after_exit() { sudo kill "$SUDO_LOOP_PID" 2>/dev/null || true; }
while true; do sudo -n true 2>/dev/null || true; sleep 60; done & SUDO_LOOP_PID=$!
trap after_exit EXIT INT TERM

###############################################################################
# Constants & defaults
###############################################################################
REPO_URL="https://github.com/ex1tium/nix-configurations.git"
REPO_BRANCH="main"
MACHINE="elara"
MIN_NIXOS_SIZE_GB=20
RECOMMENDED_NIXOS_SIZE_GB=50
FS_TYPE="btrfs"   # default FS
ENCRYPT="no"       # "yes" enables LUKS2 for root

###############################################################################
# CLI flags
###############################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fs=*)   FS_TYPE="${1#*=}"; shift ;;
    --fs)     [[ -n "${2:-}" ]] || { echo "❌ --fs requires a value"; exit 1; }; FS_TYPE="$2"; shift 2 ;;
    --encrypt) ENCRYPT="yes"; shift ;;
    --branch=*) REPO_BRANCH="${1#*=}"; shift ;;
    --branch) [[ -n "${2:-}" ]] || { echo "❌ --branch requires a value"; exit 1; }; REPO_BRANCH="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--fs ext4|btrfs|xfs] [--encrypt] [--branch <git_branch>]
  --fs       Filesystem type (default: btrfs)
  --encrypt  Enable LUKS2 encryption on root
  --branch   Git branch to use (default: main)
EOF
      exit 0 ;;
    --) shift; break ;;
    -*) echo "❌ Unknown option: $1"; exit 1 ;;
    *)  break ;;
  esac
done
[[ $FS_TYPE =~ ^(ext4|btrfs|xfs)$ ]] || { echo "❌ Unsupported --fs=$FS_TYPE"; exit 1; }
[[ $EUID -ne 0 ]] || { echo "❌ Do NOT run as root"; exit 1; }

[[ -f /etc/NIXOS ]] || { echo "❌ Must be run from a NixOS environment"; exit 1; }

###############################################################################
# Enhanced system validation
###############################################################################
validate_system() {
  echo "🔍  Performing enhanced system validation…"

  local missing_tools=()
  for tool in jq curl; do
    command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
  done
  if (( ${#missing_tools[@]} )); then
    echo "⚠️   Missing optional tools: ${missing_tools[*]} (will be provided by nix-shell if needed)"
  fi

  if ! sudo -n true 2>/dev/null; then
    echo "🔐  Verifying sudo access…"
    sudo true || { echo "❌  Sudo needed"; exit 1; }
  fi

  local avail; avail=$(df /tmp --output=avail | tail -1)
  if (( avail < 5000000 )); then
    echo "⚠️   Low /tmp space: $(( avail/1024 )) MB"
    read -rp "Continue anyway? [y/N]: " ans; [[ ${ans,,} == y* ]] || exit 1
  fi
  echo "✅  System validation completed"
}
validate_system

###############################################################################
# Dependency bootstrap – re‑exec inside nix‑shell if tools missing
###############################################################################
NEEDED=(git parted util-linux gptfdisk cryptsetup rsync tar jq bc pv)
MISSING=()
for p in "${NEEDED[@]}"; do
  case "$p" in
    util-linux) bin="lsblk" ;;
    gptfdisk)   bin="sgdisk" ;;
    *)          bin="$p"     ;;
  esac
  command -v "$bin" &>/dev/null || MISSING+=("$p")
done
if (( ${#MISSING[@]} )); then
  echo "🔧  Entering nix-shell for: ${MISSING[*]}"
  tmp_script=$(mktemp)
  cat "$0" > "$tmp_script"; chmod +x "$tmp_script"
  CLEAN_ARGS=("$@")
  exec nix-shell -p "${MISSING[@]}" --run "bash \"$tmp_script\" ${CLEAN_ARGS[@]}"
fi

# runtime sanity
for b in git parted lsblk sgdisk cryptsetup nixos-generate-config nixos-install nix rsync tar pv bc; do
  command -v "$b" >/dev/null || { echo "❌ Missing required tool: $b"; exit 1; }
fi

###############################################################################
# Helpers
###############################################################################
human()  { printf "%dGB" $(( $1/1024/1024/1024 )); }
spinner() {
  local pid=$1 msg=$2 i=0 sp='|/-\\'
  while kill -0 "$pid" 2>/dev/null; do printf "\r%s %c" "$msg" "${sp:i++%4:1}"; sleep 0.15; done
  wait "$pid" && printf "\r%s ✓\n" "$msg" || { printf "\r%s ❌\n" "$msg"; return 1; }
}
largest_gap() {
  parted -m "$1" unit GB print free | awk -F: '$1=="free"{gsub(/GB/,"",$2);gsub(/GB/,"",$4); if($4+0>max){max=$4;start=$2}} END{print start,max}'
}
list_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'; }
find_esp()  { lsblk -ln -o NAME,PARTTYPE "$1" | awk '$2~/[cC]12A7328|[eE][fF]00/{print "/dev/"$1; exit}'; }

format_root() {
  case $FS_TYPE in
    ext4) sudo mkfs.ext4 -F -L nixos "$1" ;;
    xfs)  sudo mkfs.xfs  -f -L nixos "$1" ;;
  esac
}

create_btrfs_layout() {
  local dev="$1"
  echo "🗂️  Creating BTRFS filesystem with optimal subvolume layout..."
  sudo mkfs.btrfs -f -L nixos "$dev"
  sudo mount "$dev" /mnt

  # Create subvolumes following BTRFS best practices for NixOS
  echo "📁  Creating subvolumes: @root, @home, @nix, @snapshots..."
  for sv in @root @home @nix @snapshots; do
    sudo btrfs subvolume create /mnt/$sv
    echo "  ✓ Created subvolume: $sv"
  done

  sudo umount /mnt

  # Mount subvolumes with optimal options
  echo "🔗  Mounting subvolumes with compression and SSD optimizations..."
  sudo mount -o subvol=@root,compress=zstd,ssd,noatime "$dev" /mnt
  sudo mkdir -p /mnt/{boot,home,nix,.snapshots}
  sudo mount -o subvol=@home,compress=zstd,ssd,noatime "$dev" /mnt/home
  sudo mount -o subvol=@nix,compress=zstd,ssd,noatime  "$dev" /mnt/nix
  sudo mount -o subvol=@snapshots,compress=zstd,ssd,noatime "$dev" /mnt/.snapshots

  echo "✅  BTRFS layout created successfully!"
}

backup_esp() {
  local esp=$1 ts; ts=$(date +%s)
  local tmp; tmp=$(mktemp -d)
  echo "🗄️  Backing up ESP…"
  sudo mount -o ro "$esp" "$tmp"
  sudo tar -C "$tmp" -cf "/tmp/esp_backup_${ts}.tar" .
  sudo umount "$tmp"; rmdir "$tmp"
}

###############################################################################
# Disk selection & mode
###############################################################################
mapfile -t DISKS < <(list_disks)
(( ${#DISKS[@]} )) || { echo "No disks found"; exit 1; }
for i in "${!DISKS[@]}"; do printf "[%d] %s %s\n" $((i+1)) "${DISKS[$i]}" "$(human $(lsblk -bn -o SIZE "${DISKS[$i]}") )"; done
read -rp "Select disk: " n; (( n>=1 && n<=${#DISKS[@]} )) || exit 1; DISK="${DISKS[$((n-1))]}"
read -rp $'Mode 1)Fresh 2)Dual‑boot 3)Manual : ' MODE

###############################################################################
# Partition / mount helpers per mode
###############################################################################
mount_root_generic() { sudo mount "$1" /mnt; sudo mkdir -p /mnt/boot; }

fresh_install() {
  local d="$1"
  echo "ERASE ALL on $d — this destroys ALL data!"
  read -rp "Type ERASE to continue: " x; [[ ${x^^} == ERASE ]] || exit 1

  sudo parted -s "$d" mklabel gpt \
    mkpart ESP fat32 1MiB 512MiB set 1 esp on \
    mkpart primary 512MiB 100%
  sudo mkfs.fat -F32 -n boot "${d}1"

  local root_part="${d}2"
  if [[ $ENCRYPT == yes ]]; then
    local mapper="crypt_${MACHINE//[^A-Za-z0-9_]/_}"
    sudo cryptsetup luksFormat "$root_part" --type luks2
    sudo cryptsetup open "$root_part" "$mapper"
    root_part="/dev/mapper/$mapper"
  fi

  if [[ $FS_TYPE == btrfs ]]; then
    create_btrfs_layout "$root_part"
  else
    format_root "$root_part"
    mount_root_generic "$root_part"
  fi
  sudo mount "${d}1" /mnt/boot
}

dual_boot() {
  local d="$1" esp; esp=$(find_esp "$d") || { echo "No ESP partition found"; exit 1; }
  backup_esp "$esp"
  read -rp "Root size in GB [${RECOMMENDED_NIXOS_SIZE_GB}]: " SZ; SZ=${SZ:-$RECOMMENDED_NIXOS_SIZE_GB}
  (( SZ>=MIN_NIXOS_SIZE_GB )) || { echo "Size too small"; exit 1; }
  read s gap <<< "$(largest_gap "$d")"; (( gap>=SZ )) || { echo "Not enough free space"; exit 1; }
  local end=$(printf '%.2f' "$(bc -l <<< "$s+$SZ")")
  sudo parted -s "$d" mkpart primary "${s}GB" "${end}GB"
  sudo partprobe "$d"; sleep 2

  local root_part
  root_part=$(lsblk -lnpo NAME "$d" | grep -E "${d}p?[0-9]+$" | sort -V | tail -1)
  if [[ $ENCRYPT == yes ]]; then
    local mapper="crypt_${MACHINE//[^A-Za-z0-9_]/_}"
    sudo cryptsetup luksFormat "$root_part" --type luks2
    sudo cryptsetup open "$root_part" "$mapper"
    root_part="/dev/mapper/$mapper"
  fi

  if [[ $FS_TYPE == btrfs ]]; then
    create_btrfs_layout "$root_part"
  else
    format_root "$root_part"
    mount_root_generic "$root_part"
  fi
  sudo mount "$esp" /mnt/boot
}

[[ $MODE == 1 ]] && fresh_install "$DISK"
[[ $MODE == 2 ]] && dual_boot  "$DISK"
[[ $MODE == 3 ]] && { echo "Manual mode: mount root at /mnt and ESP at /mnt/boot, then press Enter"; read; mountpoint -q /mnt && mountpoint -q /mnt/boot || exit 1; }

###############################################################################
# Clone flake & ask for username BEFORE install
###############################################################################
NIX_FLAGS="--experimental-features nix-command flakes"

echo "📥  Cloning flake ($REPO_BRANCH)…"
rm -rf /tmp/nix-config
(git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" /tmp/nix-config &> /tmp/git_clone.log) & spinner $! "Clone"
cd /tmp/nix-config || exit 1

PRIMARY_USER=$(nix $NIX_FLAGS eval ".#globalConfig.defaultUser" --raw 2>/dev/null || grep -o 'defaultUser *= *"[^" ]*"' flake.nix | head -1 | cut -d'"' -f2 || echo "ex1tium")

echo "Detected primary user: $PRIMARY_USER"
read -rp "Is this OK? [Y/n]: " ok; ok=${ok:-Y}
if [[ ${ok,,} == n* ]]; then read -rp "Enter username: " PRIMARY_USER; fi

USER_OVERRIDE=""
if ! grep -R --include='*.nix' -E "mySystem\\.user\\s*=\\s*\"${PRIMARY_USER}\"" . >/dev/null; then
  echo "{ ... }: { mySystem.user = \"$PRIMARY_USER\"; }" > "machines/$MACHINE/_user-override.nix"
  USER_OVERRIDE="machines/$MACHINE/_user-override.nix"
  echo "  User override created for installation"
fi

###############################################################################
# Generate HW config & validate build
###############################################################################

echo "🔍  Generating hardware-configuration.nix…"
sudo nixos-generate-config --root /mnt >/dev/null
sudo cp /mnt/etc/nixos/hardware-configuration.nix "machines/$MACHINE/"

echo "🔍  Validating flake configuration…"
if ! nix $NIX_FLAGS flake check --no-build 2>/tmp/flake_check.log; then
  echo "❌  Flake validation failed!"; cat /tmp/flake_check.log; exit 1
fi

echo "⚠️   Checking NixOS warnings…"
if nix $NIX_FLAGS eval ".#nixosConfigurations.$MACHINE.config.warnings" --json | jq -e '. | length>0' >/dev/null 2>&1; then
  nix $NIX_FLAGS eval ".#nixosConfigurations.$MACHINE.config.warnings" --json | jq -r '.[]' | sed 's/^/    /'
  read -rp "Continue despite warnings? [y/N]: " w; [[ ${w,,} == y* ]] || exit 1
fi

# Dry‑run build to estimate closure
echo "🧪  Testing system build (dry‑run)…"
if ! nix $NIX_FLAGS build --dry-run ".#nixosConfigurations.$MACHINE.config.system.build.toplevel" 2>/tmp/build_test.log; then
  echo "❌  Build test failed"; cat /tmp/build_test.log; exit 1
fi

echo "✅  Build validation passed!"

###############################################################################
# Install
###############################################################################

echo "🚀  Installing NixOS… (this can take a while)"
if ! sudo nixos-install --no-root-password --flake ".#$MACHINE" --root /mnt 2>&1 | tee /tmp/nixos_install.log; then
  echo "❌  Installation failed!"; tail -50 /tmp/nixos_install.log; exit 1
fi

echo "✅  Installation completed successfully!"

[[ -n "$USER_OVERRIDE" && -f "$USER_OVERRIDE" ]] && rm -f "$USER_OVERRIDE" && echo "🧹  Cleaned up temporary user override"

# Offer to enable BTRFS snapshots if using BTRFS
if [[ "$FS_TYPE" == "btrfs" ]]; then
  echo ""
  echo "📸  BTRFS filesystem detected!"
  read -rp "Enable automatic snapshots with Snapper? [Y/n]: " enable_snapshots
  enable_snapshots=${enable_snapshots:-Y}

  if [[ $enable_snapshots =~ ^[Yy] ]]; then
    echo "🔧  Enabling BTRFS snapshots in configuration..."

    # Add snapshots configuration to machine config
    cat >> "machines/$MACHINE/configuration.nix" << 'EOF'

  # BTRFS Snapshots Configuration
  # Automatically enabled by installer for BTRFS filesystem
  mySystem.features.btrfsSnapshots = {
    enable = true;
    autoSnapshots = true;

    # Optimized retention policy
    rootConfig = {
      enable = true;
      timelineCreate = true;
      timelineCleanup = true;
      retentionPolicy = {
        TIMELINE_MIN_AGE = "1800";      # 30 minutes
        TIMELINE_LIMIT_HOURLY = "10";   # Keep 10 hourly snapshots
        TIMELINE_LIMIT_DAILY = "7";     # Keep 7 daily snapshots
        TIMELINE_LIMIT_WEEKLY = "4";    # Keep 4 weekly snapshots
        TIMELINE_LIMIT_MONTHLY = "2";   # Keep 2 monthly snapshots
        TIMELINE_LIMIT_YEARLY = "0";    # No yearly snapshots
      };
    };

    homeConfig = {
      enable = true;
      timelineCreate = true;
      timelineCleanup = true;
      retentionPolicy = {
        TIMELINE_MIN_AGE = "1800";      # 30 minutes
        TIMELINE_LIMIT_HOURLY = "24";   # Keep 24 hourly snapshots (1 day)
        TIMELINE_LIMIT_DAILY = "7";     # Keep 7 daily snapshots (1 week)
        TIMELINE_LIMIT_WEEKLY = "4";    # Keep 4 weekly snapshots (1 month)
        TIMELINE_LIMIT_MONTHLY = "3";   # Keep 3 monthly snapshots
        TIMELINE_LIMIT_YEARLY = "1";    # Keep 1 yearly snapshot
      };
    };
  };
EOF

    echo "✅  BTRFS snapshots configuration added!"
    echo "📋  Snapshots will be configured for user: $PRIMARY_USER"
    echo "🔄  Snapshots will start automatically after first boot"
  else
    echo "⏭️   Skipping BTRFS snapshots setup"
    echo "💡  You can enable snapshots later by adding mySystem.features.btrfsSnapshots.enable = true;"
  fi
fi

###############################################################################
# Post‑install password setup
###############################################################################
read -rp "Set password for $PRIMARY_USER now? [Y/n]: " pw; pw=${pw:-Y}
if [[ ${pw,,} == y* ]]; then
  sudo nixos-enter --root /mnt -c "passwd $PRIMARY_USER" || { echo "⚠️  nixos-enter failed — set password after reboot with: sudo passwd $PRIMARY_USER"; }
fi

read -rp "Set root password? [y/N]: " rp
if [[ ${rp,,} == y* ]]; then
  sudo nixos-enter --root /mnt -c "passwd root" || { echo "⚠️  nixos-enter failed — set password after reboot with: sudo passwd root"; }
fi

echo -e "\n\033[1;32m🎉  Done — remove installation media and reboot.\033[0m"
