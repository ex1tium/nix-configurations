#!/usr/bin/env bash
# fedora42-lowspec-safe.sh
# Safe Fedora 42 KDE optimization for 2-core Celeron, 4GB RAM, M.2 SATA SSD
# Version: 2.0 - Safety-focused with rollback support
# Last update: 2025-07-03

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_NAME="fedora42-lowspec-safe"
readonly BACKUP_DIR="/var/backups/${SCRIPT_NAME}"
readonly LOG_FILE="/var/log/${SCRIPT_NAME}.log"

# System detection
readonly MEM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
readonly RAM_MB=$(( MEM_KB / 1024 ))
readonly ROOT_DEV=$(findmnt -n -o SOURCE /)
readonly FS_TYPE=$(findmnt -n -o FSTYPE /)

# Helper functions
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }

need_root() { 
    [[ $(id -u) -eq 0 ]] || error "This script must be run as root. Use: sudo $0"
}

need_cmd() { 
    command -v "$1" &>/dev/null || {
        log "Installing missing command: $1"
        dnf -y install "$1" || error "Failed to install $1"
    }
}

backup_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    local backup="${BACKUP_DIR}/$(basename "$file").$(date +%s)"
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$backup"
    log "Backed up $file to $backup"
}

is_configured() {
    local marker="$1"
    [[ -f "/etc/${SCRIPT_NAME}/${marker}" ]]
}

mark_configured() {
    local marker="$1"
    mkdir -p "/etc/${SCRIPT_NAME}"
    touch "/etc/${SCRIPT_NAME}/${marker}"
}

# Validation functions
validate_system() {
    info "Validating system compatibility..."
    
    # Check Fedora version
    if [[ -f /etc/fedora-release ]]; then
        local fedora_ver=$(grep -oP 'Fedora.*?(\d+)' /etc/fedora-release | grep -oP '\d+')
        [[ $fedora_ver -ge 39 ]] || warn "Fedora version $fedora_ver may not be fully supported"
    else
        error "This script is designed for Fedora systems only"
    fi
    
    # Check available RAM
    [[ $RAM_MB -ge 3500 ]] || warn "System has only ${RAM_MB}MB RAM, some optimizations may be too aggressive"
    [[ $RAM_MB -le 8192 ]] || warn "System has ${RAM_MB}MB RAM, this script is optimized for low-spec systems"
    
    # Check disk type
    if [[ $ROOT_DEV =~ ^/dev/sd ]]; then
        info "Detected SATA storage: $ROOT_DEV"
    elif [[ $ROOT_DEV =~ ^/dev/nvme ]]; then
        info "Detected NVMe storage: $ROOT_DEV"
    else
        warn "Unknown storage type: $ROOT_DEV"
    fi
    
    info "System validation complete. RAM: ${RAM_MB}MB, Storage: $ROOT_DEV, FS: $FS_TYPE"
}

# Optimization functions
setup_zram() {
    is_configured "zram" && { info "ZRAM already configured, skipping..."; return; }
    
    log "Configuring ZRAM swap..."
    local zram_mb=$(( RAM_MB * 50 / 100 ))  # Conservative 50% for 4GB systems
    
    backup_file "/etc/systemd/zram-generator.conf"
    
    cat > /etc/systemd/zram-generator.conf << EOF
[zram0]
zram-size=${zram_mb}M
compression-algorithm=zstd
swap-priority=100
EOF
    
    # Safe swappiness for low-spec systems
    backup_file "/etc/sysctl.d/99-zram.conf"
    cat > /etc/sysctl.d/99-zram.conf << EOF
# ZRAM optimizations for low-spec systems
vm.swappiness = 60
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
EOF
    
    systemctl daemon-reload
    systemctl restart systemd-zram-setup@zram0.service || warn "ZRAM setup may require reboot"
    mark_configured "zram"
    log "ZRAM configured: ${zram_mb}MB with zstd compression"
}

setup_tmpfs() {
    is_configured "tmpfs" && { info "tmpfs already configured, skipping..."; return; }
    
    log "Configuring safe tmpfs mounts..."
    backup_file "/etc/fstab"
    
    # Conservative sizes for 4GB system - only cache directories
    local tmp_size="256M"      # Reduced from 1G
    local cache_size="64M"     # Reduced from 300M
    local vartmp_size="32M"    # Reduced from 128M
    
    # Function to safely add tmpfs entries
    add_tmpfs() {
        local mnt="$1" opts="$2"
        if ! grep -qE "[[:space:]]${mnt}[[:space:]]" /etc/fstab; then
            printf "tmpfs\t%s\ttmpfs\t%s\t0 0\n" "$mnt" "$opts" >> /etc/fstab
            log "Added tmpfs for $mnt"
        fi
    }
    
    # Only safe tmpfs mounts - NO /var/log!
    add_tmpfs "/tmp" "noatime,nodev,nosuid,size=${tmp_size},mode=1777"
    add_tmpfs "/var/tmp" "noatime,nodev,nosuid,size=${vartmp_size}"
    add_tmpfs "/var/cache/dnf" "noatime,nodev,nosuid,size=${cache_size}"
    
    mark_configured "tmpfs"
    log "Safe tmpfs mounts configured (reboot required)"
}

setup_journald() {
    is_configured "journald" && { info "journald already configured, skipping..."; return; }
    
    log "Configuring journald for low-spec system..."
    mkdir -p /etc/systemd/journald.conf.d
    backup_file "/etc/systemd/journald.conf.d/lowspec.conf"
    
    cat > /etc/systemd/journald.conf.d/lowspec.conf << 'EOF'
[Journal]
# Keep logs on disk but limit size for low-spec systems
Storage=persistent
SystemMaxUse=128M
SystemKeepFree=256M
SystemMaxFileSize=16M
MaxFileSec=3day
MaxRetentionSec=1week
Compress=yes
EOF
    
    systemctl restart systemd-journald
    mark_configured "journald"
    log "journald configured with size limits"
}

setup_io_scheduler() {
    is_configured "io_scheduler" && { info "I/O scheduler already configured, skipping..."; return; }
    
    log "Configuring I/O scheduler..."
    
    # Detect storage type and set appropriate scheduler
    if [[ $ROOT_DEV =~ ^/dev/sd ]]; then
        # SATA SSD - use mq-deadline (better than bfq for SSDs)
        cat > /etc/udev/rules.d/60-sata-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="mq-deadline"
EOF
        log "Configured mq-deadline scheduler for SATA SSD"
    elif [[ $ROOT_DEV =~ ^/dev/nvme ]]; then
        # NVMe - use none
        cat > /etc/udev/rules.d/60-nvme-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
        log "Configured none scheduler for NVMe"
    fi
    
    udevadm control --reload
    mark_configured "io_scheduler"
}

setup_oomd() {
    is_configured "oomd" && { info "systemd-oomd already configured, skipping..."; return; }

    log "Configuring systemd-oomd for low-spec system..."
    mkdir -p /etc/systemd/oomd.conf.d
    backup_file "/etc/systemd/oomd.conf.d/lowspec.conf"

    cat > /etc/systemd/oomd.conf.d/lowspec.conf << 'EOF'
[OOMPolicy]
# More aggressive for low-spec systems
DefaultMemoryPressureLimit=60%
DefaultSwapUsedLimit=90%
EOF

    systemctl daemon-reload
    mark_configured "oomd"
    log "systemd-oomd configured for low-spec system"
}

setup_services() {
    is_configured "services" && { info "Services already optimized, skipping..."; return; }

    log "Optimizing system services..."

    # Only disable services that are clearly unnecessary for most users
    local services_to_disable=(
        "ModemManager.service"
        "packagekit.service"
    )

    # Ask about optional services
    local optional_services=(
        "cups.socket:Print services"
        "bluetooth.service:Bluetooth"
    )

    for service_info in "${optional_services[@]}"; do
        local service="${service_info%%:*}"
        local desc="${service_info##*:}"

        if systemctl is-enabled "$service" &>/dev/null; then
            read -p "Disable $desc ($service)? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                services_to_disable+=("$service")
            fi
        fi
    done

    # Disable selected services
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl disable --now "$service" 2>/dev/null && log "Disabled $service" || warn "Failed to disable $service"
        fi
    done

    # Enable useful services
    systemctl enable --now fstrim.timer || warn "Failed to enable fstrim.timer"

    mark_configured "services"
    log "Service optimization complete"
}

setup_power_management() {
    is_configured "power" && { info "Power management already configured, skipping..."; return; }

    log "Installing and configuring TLP for power management..."

    # Install TLP if not present
    if ! command -v tlp &>/dev/null; then
        dnf -y install tlp tlp-rdw || warn "Failed to install TLP"
    fi

    # Configure TLP for low-spec Celeron
    backup_file "/etc/tlp.conf"
    cat > /etc/tlp.d/01-lowspec.conf << 'EOF'
# TLP configuration for low-spec Celeron systems
CPU_SCALING_GOVERNOR_ON_AC=schedutil
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
SCHED_POWERSAVE_ON_AC=0
SCHED_POWERSAVE_ON_BAT=1
EOF

    systemctl enable --now tlp || warn "Failed to enable TLP"
    mark_configured "power"
    log "Power management configured"
}

setup_swap_file() {
    is_configured "swapfile" && { info "Swap file already configured, skipping..."; return; }

    local swapfile="/var/swapfile"
    local swap_gb=2  # Reduced to 2GB for 4GB system

    if ! grep -q "$swapfile" /etc/fstab; then
        log "Creating ${swap_gb}GB fallback swap file..."

        # Ensure parent directory exists and is suitable for swap
        mkdir -p /var

        # Handle Btrfs CoW if needed
        if [[ $FS_TYPE == "btrfs" ]]; then
            chattr +C /var 2>/dev/null || true
        fi

        # Create swap file
        truncate -s 0 "$swapfile"
        [[ $FS_TYPE == "btrfs" ]] && chattr +C "$swapfile" 2>/dev/null || true
        fallocate -l ${swap_gb}G "$swapfile" || dd if=/dev/zero of="$swapfile" bs=1M count=$((swap_gb * 1024))
        chmod 600 "$swapfile"
        mkswap -U clear "$swapfile"

        # Add to fstab with lower priority than ZRAM
        backup_file "/etc/fstab"
        printf "%s none swap defaults,discard,pri=10 0 0\n" "$swapfile" >> /etc/fstab
        swapon "$swapfile"

        mark_configured "swapfile"
        log "Created ${swap_gb}GB swap file with priority 10"
    fi
}

setup_kernel_params() {
    is_configured "kernel_params" && { info "Kernel parameters already configured, skipping..."; return; }

    log "Configuring kernel parameters..."

    # Safe kernel parameters for low-spec systems
    local kernel_args="mitigations=auto"

    # Only add zswap if ZRAM is not sufficient
    if [[ $RAM_MB -lt 4096 ]]; then
        kernel_args+=" zswap.enabled=1 zswap.compressor=zstd zswap.zpool=z3fold"
    fi

    grubby --update-kernel=ALL --args="$kernel_args"

    # Remove Plymouth for faster boot feedback
    grubby --update-kernel=ALL --remove-args="rhgb quiet"

    mark_configured "kernel_params"
    log "Kernel parameters configured"
}

# Main execution
main() {
    log "Starting Fedora 42 low-spec optimization..."

    need_root

    # Install required tools
    for cmd in grubby awk sed findmnt; do
        need_cmd "$cmd"
    done

    validate_system

    # Run optimizations
    setup_zram
    setup_tmpfs
    setup_journald
    setup_io_scheduler
    setup_oomd
    setup_services
    setup_power_management
    setup_swap_file
    setup_kernel_params

    # Final report
    echo
    log "✅ All optimizations applied successfully!"
    info "System specs: ${RAM_MB}MB RAM, $ROOT_DEV ($FS_TYPE)"
    info "Backup location: $BACKUP_DIR"
    info "Log file: $LOG_FILE"
    echo
    warn "⚠️  REBOOT REQUIRED to activate all changes"
    echo
    info "After reboot, verify with:"
    info "  swapon --show              # Check swap configuration"
    info "  zramctl                    # Check ZRAM status"
    info "  systemd-analyze            # Check boot time"
    info "  systemctl status tlp       # Check power management"
    info "  journalctl --disk-usage    # Check log usage"
}

# Rollback function
rollback() {
    warn "Rolling back changes..."

    if [[ -d "$BACKUP_DIR" ]]; then
        for backup in "$BACKUP_DIR"/*; do
            [[ -f "$backup" ]] || continue
            local original="/etc/$(basename "$backup" | sed 's/\.[0-9]*$//')"
            cp "$backup" "$original"
            log "Restored $original"
        done
    fi

    rm -rf "/etc/${SCRIPT_NAME}"
    warn "Rollback complete. Reboot recommended."
}

# Handle script arguments
case "${1:-}" in
    --rollback)
        rollback
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [--rollback|--help]"
        echo "  --rollback  Restore original configuration files"
        echo "  --help      Show this help message"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
