#!/usr/bin/env bash
# Quick diagnostic script to check what went wrong with the installation

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

main() {
    log_info "NixOS Installation Diagnostic Tool"
    echo
    
    # Find BTRFS partitions
    log_info "=== DISK ANALYSIS ==="
    log_info "Available disks:"
    lsblk -f
    echo
    
    # Find BTRFS partitions
    local btrfs_partitions
    mapfile -t btrfs_partitions < <(lsblk -no NAME,FSTYPE | awk '$2=="btrfs" {print "/dev/"$1}')
    
    if [[ ${#btrfs_partitions[@]} -eq 0 ]]; then
        log_error "No BTRFS partitions found"
        exit 1
    fi
    
    log_info "Found BTRFS partitions: ${btrfs_partitions[*]}"
    
    for partition in "${btrfs_partitions[@]}"; do
        log_info "=== ANALYZING $partition ==="
        
        # Get partition info
        log_info "Partition info:"
        blkid "$partition" || true
        echo
        
        # Mount and inspect
        local temp_mount="/tmp/btrfs_diag_$$"
        mkdir -p "$temp_mount"
        
        if mount "$partition" "$temp_mount" 2>/dev/null; then
            log_info "Successfully mounted $partition"
            
            # Check contents
            log_info "Root directory contents:"
            ls -la "$temp_mount/" | head -10
            echo
            
            # Check for subvolumes
            log_info "BTRFS subvolumes:"
            if btrfs subvolume list "$temp_mount" 2>/dev/null; then
                echo
                
                # Check each expected subvolume
                for sv in @root @home @nix @snapshots; do
                    if btrfs subvolume show "$temp_mount/$sv" &>/dev/null; then
                        log_success "Subvolume $sv exists"
                    else
                        log_error "Subvolume $sv MISSING"
                    fi
                done
            else
                log_error "No BTRFS subvolumes found!"
            fi
            echo
            
            # Check for system files
            log_info "System file analysis:"
            if [[ -d "$temp_mount/etc" ]]; then
                log_warn "System files found in BTRFS root (should be in @root subvolume)"
                log_info "Found directories in root:"
                find "$temp_mount" -maxdepth 1 -type d | grep -v "^$temp_mount/@" | head -5
            fi
            
            if [[ -d "$temp_mount/@root/etc" ]]; then
                log_success "System files found in @root subvolume (correct)"
            fi
            
            # Check if NixOS installation exists
            if [[ -f "$temp_mount/etc/nixos/configuration.nix" ]] || [[ -f "$temp_mount/@root/etc/nixos/configuration.nix" ]]; then
                log_success "NixOS configuration found"
                
                # Check hardware config
                local hw_config=""
                if [[ -f "$temp_mount/etc/nixos/hardware-configuration.nix" ]]; then
                    hw_config="$temp_mount/etc/nixos/hardware-configuration.nix"
                elif [[ -f "$temp_mount/@root/etc/nixos/hardware-configuration.nix" ]]; then
                    hw_config="$temp_mount/@root/etc/nixos/hardware-configuration.nix"
                fi
                
                if [[ -n "$hw_config" ]]; then
                    log_info "Hardware configuration analysis:"
                    if grep -q "subvol=@root" "$hw_config"; then
                        log_success "Hardware config has correct BTRFS subvolume options"
                    else
                        log_error "Hardware config MISSING BTRFS subvolume options"
                        log_info "Current root filesystem config:"
                        grep -A 5 'fileSystems."/"' "$hw_config" || true
                    fi
                fi
            else
                log_error "No NixOS configuration found"
            fi
            
            umount "$temp_mount"
        else
            log_error "Failed to mount $partition"
        fi
        
        rmdir "$temp_mount"
        echo "----------------------------------------"
    done
    
    # Check installation logs
    log_info "=== INSTALLATION LOG ANALYSIS ==="
    local log_files
    mapfile -t log_files < <(find /tmp -name "nixos-install-*.log" 2>/dev/null | sort -r)
    
    if [[ ${#log_files[@]} -gt 0 ]]; then
        log_info "Found installation logs:"
        for log_file in "${log_files[@]}"; do
            echo "  $log_file"
        done
        echo
        
        log_info "Checking latest log for BTRFS operations:"
        local latest_log="${log_files[0]}"
        
        if grep -q "Creating BTRFS subvolume" "$latest_log"; then
            log_success "Log shows subvolume creation attempts"
            grep "Creating BTRFS subvolume" "$latest_log"
        else
            log_error "No subvolume creation found in logs"
        fi
        
        if grep -q "DRY-RUN" "$latest_log"; then
            log_error "Installation was run in DRY-RUN mode!"
            log_info "DRY-RUN entries found:"
            grep "DRY-RUN" "$latest_log" | head -5
        else
            log_info "Installation was not in dry-run mode"
        fi
        
        if grep -q "ERROR\|Failed" "$latest_log"; then
            log_warn "Errors found in installation log:"
            grep "ERROR\|Failed" "$latest_log" | tail -5
        fi
    else
        log_warn "No installation logs found in /tmp"
    fi
    
    echo
    log_info "=== DIAGNOSIS COMPLETE ==="
    log_info "Run the repair script to fix identified issues:"
    log_info "  sudo ./scripts/repair_boot.sh"
}

main "$@"
