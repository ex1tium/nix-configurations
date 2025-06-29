#!/usr/bin/env bash
# Debug UUID detection issues

set -euo pipefail

# Load common functions
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

main() {
    print_box "$CYAN" "🔍 UUID Debug Analysis 🔍" \
        "${WHITE}This script will analyze UUID detection issues" \
        "${YELLOW}Run this from NixOS live environment with /mnt mounted"
    echo

    if [[ ! -d /mnt ]]; then
        log_error "/mnt not found - please mount your installation first"
        exit 1
    fi

    log_info "=== FILESYSTEM ANALYSIS ==="
    
    # Show all block devices
    log_info "All block devices:"
    lsblk -f
    echo
    
    # Show what's mounted
    log_info "Current mounts:"
    findmnt | grep -E "(mnt|sda|vda)" || log_warn "No relevant mounts found"
    echo
    
    # Check BTRFS filesystems specifically
    log_info "BTRFS filesystems:"
    lsblk -f | grep btrfs || log_warn "No BTRFS filesystems found"
    echo
    
    # Get UUIDs using different methods
    log_info "=== UUID DETECTION METHODS ==="
    
    # Method 1: findmnt (what our script uses)
    log_info "Method 1 - findmnt:"
    local uuid_findmnt
    uuid_findmnt=$(findmnt -n -o UUID /mnt 2>/dev/null || echo "FAILED")
    log_info "  findmnt UUID: $uuid_findmnt"
    
    # Method 2: Get source device and use blkid
    log_info "Method 2 - blkid on source device:"
    local source_device
    source_device=$(findmnt -n -o SOURCE /mnt 2>/dev/null || echo "FAILED")
    log_info "  Source device: $source_device"
    
    if [[ "$source_device" != "FAILED" && "$source_device" =~ ^/dev/ ]]; then
        local uuid_blkid
        uuid_blkid=$(blkid -s UUID -o value "$source_device" 2>/dev/null || echo "FAILED")
        log_info "  blkid UUID: $uuid_blkid"
    fi
    
    # Method 3: Check all BTRFS devices
    log_info "Method 3 - All BTRFS device UUIDs:"
    while IFS= read -r device; do
        if [[ -n "$device" ]]; then
            local dev_uuid
            dev_uuid=$(blkid -s UUID -o value "$device" 2>/dev/null || echo "FAILED")
            log_info "  $device: $dev_uuid"
        fi
    done < <(lsblk -f -n -o NAME,FSTYPE | grep btrfs | awk '{print "/dev/"$1}')
    
    echo
    log_info "=== HARDWARE CONFIG ANALYSIS ==="
    
    local hw_config="/mnt/etc/nixos/hardware-configuration.nix"
    if [[ -f "$hw_config" ]]; then
        log_info "Current hardware configuration:"
        echo "--- ROOT FILESYSTEM ---"
        grep -A 4 'fileSystems."/"' "$hw_config" || log_warn "Root filesystem config not found"
        echo
        
        # Extract UUID from hardware config
        local config_uuid
        config_uuid=$(grep -A 4 'fileSystems."/"' "$hw_config" | grep "device.*by-uuid" | sed 's/.*by-uuid\/\([^"]*\).*/\1/' || echo "NOT_FOUND")
        log_info "UUID in hardware config: $config_uuid"
        
        # Check if this UUID exists in the system
        if [[ "$config_uuid" != "NOT_FOUND" ]]; then
            if [[ -e "/dev/disk/by-uuid/$config_uuid" ]]; then
                log_success "✅ UUID $config_uuid exists in /dev/disk/by-uuid/"
                local real_device
                real_device=$(readlink -f "/dev/disk/by-uuid/$config_uuid")
                log_info "  Points to: $real_device"
            else
                log_error "❌ UUID $config_uuid NOT found in /dev/disk/by-uuid/"
                log_info "Available UUIDs:"
                ls -la /dev/disk/by-uuid/ | head -10
            fi
        fi
    else
        log_error "Hardware configuration not found at $hw_config"
    fi
    
    echo
    log_info "=== BTRFS SUBVOLUME ANALYSIS ==="
    
    # Check BTRFS subvolumes
    local btrfs_devices
    mapfile -t btrfs_devices < <(lsblk -f -n -o NAME,FSTYPE | grep btrfs | awk '{print "/dev/"$1}')
    
    for device in "${btrfs_devices[@]}"; do
        log_info "BTRFS device: $device"
        
        # Try to mount and check subvolumes
        local temp_mount="/tmp/btrfs_check_$$"
        mkdir -p "$temp_mount"
        
        if mount "$device" "$temp_mount" 2>/dev/null; then
            log_info "  Subvolumes:"
            btrfs subvolume list "$temp_mount" 2>/dev/null | while read -r line; do
                log_info "    $line"
            done
            umount "$temp_mount"
        else
            log_warn "  Could not mount $device for subvolume analysis"
        fi
        
        rmdir "$temp_mount" 2>/dev/null || true
    done
    
    echo
    log_info "=== RECOMMENDATIONS ==="
    
    # Compare UUIDs and provide recommendations
    if [[ "$uuid_findmnt" != "FAILED" && "$config_uuid" != "NOT_FOUND" ]]; then
        if [[ "$uuid_findmnt" == "$config_uuid" ]]; then
            log_success "✅ UUIDs match - hardware config should be correct"
            log_info "The boot issue may be caused by missing kernel modules or other factors"
        else
            log_error "❌ UUID mismatch detected!"
            log_info "  findmnt reports: $uuid_findmnt"
            log_info "  hardware config has: $config_uuid"
            log_info "This is likely the cause of boot failures"
        fi
    else
        log_warn "Could not compare UUIDs due to detection failures"
    fi
}

main "$@"
