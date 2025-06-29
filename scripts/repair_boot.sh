#!/usr/bin/env bash
# NixOS Boot Repair Script
# Fixes BTRFS subvolume boot issues

set -euo pipefail

# Load common functions for consistent colorful logging
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Check if running from NixOS live environment
if ! command -v nixos-generate-config &> /dev/null; then
    log_error "This script must be run from a NixOS live environment"
    exit 1
fi

main() {
    print_box "$CYAN" "🔧 NixOS Boot Repair Tool 🔧" \
        "${WHITE}This script will attempt to fix BTRFS subvolume boot issues" \
        "${YELLOW}Please ensure you're running from a NixOS live environment"
    echo

    # Step 1: Detect the problematic installation
    detect_installation

    # Step 1.5: Diagnose the current state
    diagnose_current_state

    # Step 2: Mount the filesystem
    mount_filesystem

    # Step 3: Verify and fix hardware configuration
    fix_hardware_config

    # Step 4: Reinstall bootloader
    reinstall_bootloader

    # Step 5: Cleanup
    cleanup_mounts

    echo
    print_box "$GREEN" "✅ BOOT REPAIR COMPLETE! ✅" \
        "${WHITE}Your NixOS system should now boot properly" \
        "${CYAN}🚀 Remove the live media and reboot: ${YELLOW}sudo reboot"
}

diagnose_current_state() {
    log_info "Diagnosing current BTRFS state..."

    # Check what's actually on the BTRFS filesystem
    log_info "Mounting $ROOT_DEVICE to inspect contents..."
    mkdir -p /tmp/btrfs_inspect

    if mount "$ROOT_DEVICE" /tmp/btrfs_inspect; then
        log_info "Contents of BTRFS root:"
        ls -la /tmp/btrfs_inspect/

        log_info "Checking for subvolumes:"
        btrfs subvolume list /tmp/btrfs_inspect 2>/dev/null || log_warn "No subvolumes found"

        log_info "Checking for system files:"
        if [[ -d /tmp/btrfs_inspect/etc ]]; then
            log_info "Found /etc directory - system files exist in root"
        fi

        if [[ -d /tmp/btrfs_inspect/@root ]]; then
            log_info "Found @root subvolume directory"
            ls -la /tmp/btrfs_inspect/@root/ | head -5
        fi

        umount /tmp/btrfs_inspect
    else
        log_error "Failed to mount $ROOT_DEVICE for inspection"
    fi

    rmdir /tmp/btrfs_inspect
}

detect_installation() {
    log_info "Detecting NixOS installation..."
    
    # Find BTRFS partitions
    local btrfs_partitions
    mapfile -t btrfs_partitions < <(lsblk -no NAME,FSTYPE | awk '$2=="btrfs" {print "/dev/"$1}')
    
    if [[ ${#btrfs_partitions[@]} -eq 0 ]]; then
        log_error "No BTRFS partitions found"
        exit 1
    fi
    
    log_info "Found BTRFS partitions: ${btrfs_partitions[*]}"
    
    # Use the first BTRFS partition (usually the root)
    ROOT_DEVICE="${btrfs_partitions[0]}"
    log_info "Using root device: $ROOT_DEVICE"
    
    # Find ESP partition
    local esp_partitions
    mapfile -t esp_partitions < <(lsblk -no NAME,FSTYPE | awk '$2=="vfat" {print "/dev/"$1}')
    
    if [[ ${#esp_partitions[@]} -eq 0 ]]; then
        log_error "No ESP (EFI System Partition) found"
        exit 1
    fi
    
    ESP_DEVICE="${esp_partitions[0]}"
    log_info "Using ESP device: $ESP_DEVICE"
}

mount_filesystem() {
    log_info "Mounting filesystem for repair..."
    
    # Unmount any existing mounts
    umount -R /mnt 2>/dev/null || true
    
    # Create mount point
    mkdir -p /mnt
    
    # Mount root subvolume
    log_info "Mounting @root subvolume..."
    if ! mount -o subvol=@root,compress=zstd "$ROOT_DEVICE" /mnt; then
        log_error "Failed to mount @root subvolume"
        log_info "Attempting to mount without subvolume option to diagnose..."

        if mount "$ROOT_DEVICE" /mnt; then
            # Check if subvolumes exist
            log_info "Checking for existing subvolumes..."
            btrfs subvolume list /mnt 2>/dev/null || log_warn "No subvolumes found"

            if ! btrfs subvolume show /mnt/@root &>/dev/null; then
                log_error "@root subvolume does not exist. The installation is incomplete."
                log_info "This suggests the installation failed during BTRFS subvolume creation."
                log_info "You may need to reinstall NixOS completely."

                # Attempt to create subvolumes as a last resort
                log_warn "Attempting to create missing subvolumes..."
                create_missing_subvolumes

                # Try to migrate existing files if they exist in root
                if [[ -d /mnt/etc ]] && [[ ! -d /mnt/@root/etc ]]; then
                    log_info "Found system files in root, attempting migration..."
                    migrate_files_to_subvolumes
                fi

                umount /mnt
                if ! mount -o subvol=@root,compress=zstd "$ROOT_DEVICE" /mnt; then
                    log_error "Still cannot mount @root subvolume after creation"
                    exit 1
                fi
            else
                log_error "@root subvolume exists but mount failed - checking mount options"
                umount /mnt
                # Try without compression first
                if mount -o subvol=@root "$ROOT_DEVICE" /mnt; then
                    log_warn "Mounted without compression - there may be filesystem issues"
                else
                    log_error "Cannot mount @root subvolume even without compression"
                    exit 1
                fi
            fi
        else
            log_error "Cannot mount $ROOT_DEVICE at all - filesystem may be corrupted"
            exit 1
        fi
    fi
    
    # Create directories and mount other subvolumes
    mkdir -p /mnt/{home,nix,.snapshots,boot}
    
    log_info "Mounting other subvolumes..."
    mount -o subvol=@home,compress=zstd "$ROOT_DEVICE" /mnt/home
    mount -o subvol=@nix,compress=zstd "$ROOT_DEVICE" /mnt/nix
    mount -o subvol=@snapshots,compress=zstd "$ROOT_DEVICE" /mnt/.snapshots
    
    # Mount ESP
    log_info "Mounting ESP..."
    mount "$ESP_DEVICE" /mnt/boot
    
    log_success "Filesystem mounted successfully"
}

create_missing_subvolumes() {
    log_warn "Creating missing BTRFS subvolumes..."

    for sv in @root @home @nix @snapshots; do
        if ! btrfs subvolume show "/mnt/$sv" &>/dev/null; then
            log_info "Creating subvolume: $sv"
            if ! btrfs subvolume create "/mnt/$sv"; then
                log_error "Failed to create subvolume: $sv"
                return 1
            fi
        else
            log_info "Subvolume $sv already exists"
        fi
    done

    log_success "BTRFS subvolumes created successfully"
}

migrate_files_to_subvolumes() {
    log_warn "Attempting to migrate existing files to @root subvolume..."

    # This is a risky operation - create backup first
    if [[ -d /mnt/etc ]]; then
        log_info "Found system files in BTRFS root, migrating to @root subvolume..."

        # Create a list of directories to migrate (exclude subvolume directories)
        local dirs_to_migrate=()
        for item in /mnt/*; do
            if [[ -d "$item" ]] && [[ "$(basename "$item")" != @* ]]; then
                dirs_to_migrate+=("$(basename "$item")")
            fi
        done

        # Also migrate files in root
        local files_to_migrate=()
        for item in /mnt/*; do
            if [[ -f "$item" ]]; then
                files_to_migrate+=("$(basename "$item")")
            fi
        done

        if [[ ${#dirs_to_migrate[@]} -gt 0 ]] || [[ ${#files_to_migrate[@]} -gt 0 ]]; then
            log_info "Migrating directories: ${dirs_to_migrate[*]}"
            log_info "Migrating files: ${files_to_migrate[*]}"

            # Move directories
            for dir in "${dirs_to_migrate[@]}"; do
                if [[ -d "/mnt/$dir" ]]; then
                    log_info "Moving directory: $dir"
                    mv "/mnt/$dir" "/mnt/@root/" || log_warn "Failed to move $dir"
                fi
            done

            # Move files
            for file in "${files_to_migrate[@]}"; do
                if [[ -f "/mnt/$file" ]]; then
                    log_info "Moving file: $file"
                    mv "/mnt/$file" "/mnt/@root/" || log_warn "Failed to move $file"
                fi
            done

            log_success "File migration completed"
        else
            log_info "No files to migrate"
        fi
    else
        log_info "No system files found to migrate"
    fi
}

fix_hardware_config() {
    log_info "Fixing hardware configuration..."
    
    local hw_config="/mnt/etc/nixos/hardware-configuration.nix"
    
    if [[ ! -f "$hw_config" ]]; then
        log_warn "Hardware configuration not found, generating new one..."
        nixos-generate-config --root /mnt
    fi
    
    # Get the UUID of the root device
    local root_uuid
    root_uuid=$(blkid -s UUID -o value "$ROOT_DEVICE")
    
    if [[ -z "$root_uuid" ]]; then
        log_error "Could not determine root device UUID"
        exit 1
    fi
    
    log_info "Root device UUID: $root_uuid"
    
    # Check if hardware config has correct BTRFS subvolume options
    if ! grep -q "subvol=@root" "$hw_config"; then
        log_warn "Hardware config missing BTRFS subvolume options, fixing..."
        
        # Backup original
        cp "$hw_config" "${hw_config}.backup"
        
        # Create corrected hardware config
        cat > "${hw_config}.new" << EOF
# Do not modify this file!  It was generated by 'nixos-generate-config'
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" ];
  };

  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-uuid/$root_uuid";
    fsType = "btrfs";
    options = [ "subvol=@snapshots" "compress=zstd" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/$(blkid -s UUID -o value "$ESP_DEVICE")";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
EOF
        
        # Replace the hardware config
        mv "${hw_config}.new" "$hw_config"
        log_success "Hardware configuration fixed"
    else
        log_info "Hardware configuration looks correct"
    fi
}

reinstall_bootloader() {
    log_info "Reinstalling bootloader..."
    
    # Bind mount necessary filesystems
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    
    # Reinstall bootloader using nixos-rebuild
    if chroot /mnt nixos-rebuild boot; then
        log_success "Bootloader reinstalled successfully"
    else
        log_error "Failed to reinstall bootloader"
        exit 1
    fi
}

cleanup_mounts() {
    log_info "Cleaning up mounts..."
    
    # Unmount bind mounts
    umount /mnt/dev /mnt/proc /mnt/sys 2>/dev/null || true
    
    # Unmount filesystem
    umount -R /mnt 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Trap to ensure cleanup on exit
trap cleanup_mounts EXIT

# Run main function
main "$@"
