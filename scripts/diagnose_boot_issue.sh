#!/usr/bin/env bash
# NixOS Boot Issue Diagnostic Script
# Comprehensive analysis of BTRFS and boot configuration issues

set -euo pipefail

# Load common functions for consistent colorful logging
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

main() {
    print_box "$CYAN" "🔍 NixOS Boot Issue Diagnostic Tool 🔍" \
        "${WHITE}This script will analyze your NixOS installation for boot issues" \
        "${YELLOW}Run this from a NixOS live environment"
    echo

    # Step 1: Detect storage devices and partitions
    detect_storage_layout

    # Step 2: Analyze BTRFS filesystems
    analyze_btrfs_filesystems

    # Step 3: Check hardware configuration
    check_hardware_configuration

    # Step 4: Verify bootloader configuration
    check_bootloader_configuration

    # Step 5: Provide recommendations
    provide_recommendations

    echo
    print_box "$GREEN" "🎯 DIAGNOSIS COMPLETE! 🎯" \
        "${WHITE}Review the findings above for next steps" \
        "${CYAN}Consider running repair_boot.sh if issues were found"
}

detect_storage_layout() {
    log_info "🔍 Detecting storage layout..."
    echo
    
    log_info "Available block devices:"
    lsblk -f
    echo
    
    log_info "Partition table information:"
    for disk in /dev/sd? /dev/nvme?n? /dev/vd?; do
        if [[ -b "$disk" ]]; then
            echo "=== $disk ==="
            fdisk -l "$disk" 2>/dev/null | grep -E "(Disk|Device|Type)" || true
            echo
        fi
    done
}

analyze_btrfs_filesystems() {
    log_info "🔍 Analyzing BTRFS filesystems..."
    echo
    
    # Find all BTRFS partitions
    local btrfs_partitions
    mapfile -t btrfs_partitions < <(lsblk -no NAME,FSTYPE | awk '$2=="btrfs" {print "/dev/"$1}')
    
    if [[ ${#btrfs_partitions[@]} -eq 0 ]]; then
        log_warn "No BTRFS partitions found"
        return 0
    fi
    
    for partition in "${btrfs_partitions[@]}"; do
        log_info "Analyzing BTRFS partition: $partition"
        
        # Get UUID
        local uuid
        uuid=$(blkid -s UUID -o value "$partition" 2>/dev/null || echo "Unknown")
        log_info "  UUID: $uuid"
        
        # Mount and inspect
        local temp_mount="/tmp/btrfs_inspect_$$"
        mkdir -p "$temp_mount"
        
        if mount "$partition" "$temp_mount" 2>/dev/null; then
            log_info "  Successfully mounted for inspection"
            
            # Check for subvolumes
            log_info "  Subvolumes found:"
            local subvolumes
            subvolumes=$(btrfs subvolume list "$temp_mount" 2>/dev/null || echo "None")
            if [[ "$subvolumes" == "None" ]]; then
                log_warn "    No subvolumes found!"
            else
                echo "$subvolumes" | while read -r line; do
                    log_info "    $line"
                done
            fi
            
            # Check for expected subvolumes
            local expected_subvols=("@root" "@home" "@nix" "@snapshots")
            for subvol in "${expected_subvols[@]}"; do
                if [[ -d "$temp_mount/$subvol" ]]; then
                    if btrfs subvolume show "$temp_mount/$subvol" &>/dev/null; then
                        log_success "    ✅ $subvol exists and is a valid subvolume"
                    else
                        log_warn "    ⚠️  $subvol directory exists but is not a subvolume"
                    fi
                else
                    log_error "    ❌ $subvol missing"
                fi
            done
            
            # Check for system files
            log_info "  System file analysis:"
            if [[ -d "$temp_mount/etc" ]]; then
                log_warn "    ⚠️  System files found in BTRFS root (should be in @root)"
            fi
            
            if [[ -d "$temp_mount/@root/etc" ]]; then
                log_success "    ✅ System files found in @root subvolume"
            fi
            
            umount "$temp_mount"
        else
            log_error "  Failed to mount $partition"
        fi
        
        rmdir "$temp_mount"
        echo
    done
}

check_hardware_configuration() {
    log_info "🔍 Checking hardware configuration..."
    echo
    
    # Try to mount the root filesystem to check hardware config
    local btrfs_partitions
    mapfile -t btrfs_partitions < <(lsblk -no NAME,FSTYPE | awk '$2=="btrfs" {print "/dev/"$1}')
    
    if [[ ${#btrfs_partitions[@]} -eq 0 ]]; then
        log_warn "No BTRFS partitions to check"
        return 0
    fi
    
    local root_partition="${btrfs_partitions[0]}"
    local temp_mount="/tmp/nixos_check_$$"
    mkdir -p "$temp_mount"
    
    # Try mounting with @root subvolume first
    if mount -o subvol=@root "$root_partition" "$temp_mount" 2>/dev/null; then
        log_success "Successfully mounted @root subvolume"
        
        local hw_config="$temp_mount/etc/nixos/hardware-configuration.nix"
        if [[ -f "$hw_config" ]]; then
            log_info "Hardware configuration found, analyzing..."
            
            # Check for BTRFS subvolume options
            if grep -q "subvol=@root" "$hw_config"; then
                log_success "  ✅ Root subvolume option found"
            else
                log_error "  ❌ Root subvolume option missing"
            fi
            
            if grep -q "subvol=@home" "$hw_config"; then
                log_success "  ✅ Home subvolume option found"
            else
                log_error "  ❌ Home subvolume option missing"
            fi
            
            if grep -q "subvol=@nix" "$hw_config"; then
                log_success "  ✅ Nix subvolume option found"
            else
                log_error "  ❌ Nix subvolume option missing"
            fi
            
            # Check UUIDs
            local config_uuid
            config_uuid=$(grep -o 'by-uuid/[^"]*' "$hw_config" | head -1 | cut -d'/' -f2)
            local actual_uuid
            actual_uuid=$(blkid -s UUID -o value "$root_partition")
            
            if [[ "$config_uuid" == "$actual_uuid" ]]; then
                log_success "  ✅ UUID in config matches actual filesystem"
            else
                log_error "  ❌ UUID mismatch - Config: $config_uuid, Actual: $actual_uuid"
            fi
            
        else
            log_error "Hardware configuration file not found"
        fi
        
        umount "$temp_mount"
    else
        log_error "Cannot mount @root subvolume - this is the likely cause of boot failure"
        
        # Try mounting without subvolume
        if mount "$root_partition" "$temp_mount" 2>/dev/null; then
            log_info "Can mount BTRFS root, checking structure..."
            
            if [[ -d "$temp_mount/@root" ]]; then
                log_info "  @root directory exists"
                if btrfs subvolume show "$temp_mount/@root" &>/dev/null; then
                    log_success "  @root is a valid subvolume"
                else
                    log_error "  @root is a directory but not a subvolume!"
                fi
            else
                log_error "  @root directory does not exist"
            fi
            
            umount "$temp_mount"
        else
            log_error "Cannot mount BTRFS filesystem at all"
        fi
    fi
    
    rmdir "$temp_mount"
    echo
}

check_bootloader_configuration() {
    log_info "🔍 Checking bootloader configuration..."
    echo
    
    # Find ESP partitions
    local esp_partitions
    mapfile -t esp_partitions < <(lsblk -no NAME,FSTYPE | awk '$2=="vfat" {print "/dev/"$1}')
    
    if [[ ${#esp_partitions[@]} -eq 0 ]]; then
        log_error "No ESP (EFI System Partition) found"
        return 1
    fi
    
    for esp in "${esp_partitions[@]}"; do
        log_info "Checking ESP: $esp"
        
        local temp_mount="/tmp/esp_check_$$"
        mkdir -p "$temp_mount"
        
        if mount "$esp" "$temp_mount" 2>/dev/null; then
            log_success "  Successfully mounted ESP"
            
            # Check for bootloader files
            if [[ -d "$temp_mount/EFI/systemd" ]]; then
                log_success "  ✅ systemd-boot found"
            else
                log_warn "  ⚠️  systemd-boot not found"
            fi
            
            if [[ -d "$temp_mount/EFI/nixos" ]]; then
                log_success "  ✅ NixOS boot entries found"
            else
                log_warn "  ⚠️  NixOS boot entries not found"
            fi
            
            # List boot entries
            if [[ -d "$temp_mount/loader/entries" ]]; then
                local entries
                entries=$(ls "$temp_mount/loader/entries"/*.conf 2>/dev/null | wc -l)
                log_info "  Boot entries found: $entries"
            fi
            
            umount "$temp_mount"
        else
            log_error "  Failed to mount ESP"
        fi
        
        rmdir "$temp_mount"
    done
    echo
}

provide_recommendations() {
    log_info "🎯 Recommendations based on diagnosis:"
    echo
    
    print_box "$YELLOW" "🔧 RECOMMENDED ACTIONS 🔧" \
        "${WHITE}Based on the diagnosis above:" \
        "" \
        "${CYAN}1. If BTRFS subvolumes are missing or invalid:" \
        "${WHITE}   Run: sudo ./scripts/repair_boot.sh" \
        "" \
        "${CYAN}2. If hardware configuration is incorrect:" \
        "${WHITE}   The repair script will fix this automatically" \
        "" \
        "${CYAN}3. If bootloader is missing:" \
        "${WHITE}   The repair script will reinstall it" \
        "" \
        "${CYAN}4. If the installation is completely broken:" \
        "${WHITE}   Consider reinstalling with: ./scripts/install_nixos.sh" \
        "" \
        "${RED}⚠️  Always backup important data before running repair operations!"
}

# Run main function
main "$@"
