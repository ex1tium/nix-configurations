#!/usr/bin/env bash
# Simple manual installation following standard NixOS process exactly

set -euo pipefail

# Load common functions
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

main() {
    print_box "$CYAN" "📋 Manual NixOS Installation Guide 📋" \
        "${WHITE}This follows the exact standard NixOS installation process" \
        "${YELLOW}Run each step manually to identify where the difference is"
    echo

    log_info "=== STEP 1: Partition Setup ==="
    echo "Run these commands manually:"
    echo
    echo "# Identify your disk"
    echo "lsblk"
    echo
    echo "# Partition the disk (replace /dev/sda with your disk)"
    echo "sudo parted /dev/sda -- mklabel gpt"
    echo "sudo parted /dev/sda -- mkpart ESP fat32 1MB 512MB"
    echo "sudo parted /dev/sda -- set 1 esp on"
    echo "sudo parted /dev/sda -- mkpart primary 512MB 100%"
    echo
    echo "# Format partitions"
    echo "sudo mkfs.fat -F 32 -n boot /dev/sda1"
    echo "sudo mkfs.btrfs -L nixos /dev/sda2"
    echo
    
    read -p "Press Enter after completing partitioning..."
    
    log_info "=== STEP 2: BTRFS Subvolumes (Standard Way) ==="
    echo "Run these commands manually:"
    echo
    echo "# Mount the BTRFS filesystem"
    echo "sudo mount /dev/sda2 /mnt"
    echo
    echo "# Create subvolumes (NixOS standard naming)"
    echo "sudo btrfs subvolume create /mnt/root"
    echo "sudo btrfs subvolume create /mnt/home"
    echo "sudo btrfs subvolume create /mnt/nix"
    echo "sudo btrfs subvolume create /mnt/snapshots"
    echo
    echo "# Unmount"
    echo "sudo umount /mnt"
    echo
    
    read -p "Press Enter after creating subvolumes..."
    
    log_info "=== STEP 3: Mount Subvolumes (Standard Way) ==="
    echo "Run these commands manually:"
    echo
    echo "# Mount root subvolume"
    echo "sudo mount -o subvol=root,compress=zstd /dev/sda2 /mnt"
    echo
    echo "# Create mount points"
    echo "sudo mkdir -p /mnt/{home,nix,.snapshots,boot}"
    echo
    echo "# Mount other subvolumes"
    echo "sudo mount -o subvol=home,compress=zstd /dev/sda2 /mnt/home"
    echo "sudo mount -o subvol=nix,compress=zstd,noatime /dev/sda2 /mnt/nix"
    echo "sudo mount -o subvol=snapshots,compress=zstd /dev/sda2 /mnt/.snapshots"
    echo
    echo "# Mount boot"
    echo "sudo mount /dev/sda1 /mnt/boot"
    echo
    
    read -p "Press Enter after mounting..."
    
    log_info "=== STEP 4: Verify Mounts ==="
    echo "Check that everything is mounted correctly:"
    echo
    echo "findmnt | grep mnt"
    echo "lsblk"
    echo
    
    read -p "Press Enter after verifying mounts..."
    
    log_info "=== STEP 5: Generate Hardware Config ==="
    echo "Run these commands manually:"
    echo
    echo "# Generate hardware configuration"
    echo "sudo nixos-generate-config --root /mnt"
    echo
    echo "# Check what was generated"
    echo "cat /mnt/etc/nixos/hardware-configuration.nix"
    echo
    echo "Look for:"
    echo "- fsType = \"btrfs\""
    echo "- options = [ \"subvol=root\" \"compress=zstd\" ]"
    echo "- options = [ \"subvol=nix\" \"compress=zstd\" \"noatime\" ] for /nix"
    echo "- boot.supportedFilesystems = [ \"btrfs\" ];"
    echo "- Correct UUIDs"
    echo
    
    read -p "Press Enter after checking hardware config..."
    
    log_info "=== STEP 6: Copy Your Configuration ==="
    echo "Run these commands manually:"
    echo
    echo "# Clone your repo"
    echo "git clone https://github.com/ex1tium/nix-configurations.git /tmp/nix-config"
    echo
    echo "# Copy machine configuration"
    echo "sudo cp -r /tmp/nix-config/machines/elara /mnt/etc/nixos/"
    echo "sudo cp /tmp/nix-config/flake.* /mnt/etc/nixos/"
    echo "sudo cp -r /tmp/nix-config/modules /mnt/etc/nixos/"
    echo
    echo "# Or use your existing configuration method"
    echo
    
    read -p "Press Enter after copying configuration..."
    
    log_info "=== STEP 7: Install ==="
    echo "Run the installation:"
    echo
    echo "# Standard NixOS install"
    echo "sudo nixos-install --no-root-password"
    echo
    echo "# OR with flake"
    echo "cd /mnt/etc/nixos"
    echo "sudo nixos-install --no-root-password --flake '.#elara'"
    echo
    
    read -p "Press Enter after installation completes..."
    
    log_info "=== STEP 8: Final Check ==="
    echo "Before rebooting, verify:"
    echo
    echo "# Check hardware config one more time"
    echo "cat /mnt/etc/nixos/hardware-configuration.nix | grep -A 10 'fileSystems'"
    echo
    echo "# Check that UUIDs exist"
    echo "ls -la /dev/disk/by-uuid/"
    echo
    echo "# Verify BTRFS subvolumes"
    echo "sudo btrfs subvolume list /mnt"
    echo
    
    log_success "Manual installation guide complete!"
    log_info "If this works, we can identify what our automated script does differently"
    log_info "If this fails, the issue is more fundamental"
}

main "$@"
