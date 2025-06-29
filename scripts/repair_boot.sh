#!/usr/bin/env bash
# NixOS Boot Repair Script
# Fixes BTRFS subvolume boot issues

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
    log_info "NixOS Boot Repair Tool"
    echo "This script will attempt to fix BTRFS subvolume boot issues"
    echo

    # Step 1: Detect the problematic installation
    detect_installation

    # Step 2: Mount the filesystem
    mount_filesystem

    # Step 3: Verify and fix hardware configuration
    fix_hardware_config

    # Step 4: Reinstall bootloader
    reinstall_bootloader

    # Step 5: Cleanup
    cleanup_mounts

    log_success "Boot repair completed! Try rebooting now."
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
        log_info "Attempting to mount without subvolume option..."
        mount "$ROOT_DEVICE" /mnt
        
        # Check if subvolumes exist
        if ! btrfs subvolume show /mnt/@root &>/dev/null; then
            log_error "@root subvolume does not exist. Creating subvolumes..."
            create_missing_subvolumes
            umount /mnt
            mount -o subvol=@root,compress=zstd "$ROOT_DEVICE" /mnt
        else
            log_error "@root subvolume exists but mount failed"
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
            btrfs subvolume create "/mnt/$sv"
        fi
    done
    
    # If @root was missing, we need to copy existing files
    if [[ -d /mnt/etc ]] && ! btrfs subvolume show /mnt/@root &>/dev/null; then
        log_info "Moving existing files to @root subvolume..."
        # This is a complex operation - for now, just create empty subvolume
        log_warn "Manual file migration may be required"
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
