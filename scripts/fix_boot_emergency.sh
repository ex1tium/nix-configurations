#!/usr/bin/env bash
# Emergency boot fix script
# Run this from NixOS installation media to fix the boot issue

set -euo pipefail

echo "🚨 Emergency Boot Fix for NixOS Installation"
echo "=============================================="
echo

# UUIDs from the installation log
ROOT_UUID="d9604f3f-c714-479d-9e7c-3c4131fd5271"
BOOT_UUID="C6B3-5712"

echo "📋 Using UUIDs from installation:"
echo "   Root: $ROOT_UUID"
echo "   Boot: $BOOT_UUID"
echo

# Mount the installed system
echo "🔗 Mounting installed system..."
sudo mount -o subvol=root /dev/disk/by-uuid/$ROOT_UUID /mnt
sudo mount -o subvol=home /dev/disk/by-uuid/$ROOT_UUID /mnt/home
sudo mount -o subvol=nix /dev/disk/by-uuid/$ROOT_UUID /mnt/nix
sudo mount -o subvol=snapshots /dev/disk/by-uuid/$ROOT_UUID /mnt/.snapshots
sudo mount /dev/disk/by-uuid/$BOOT_UUID /mnt/boot

echo "✅ System mounted successfully"

# Clone the updated configuration
echo "📥 Getting updated configuration..."
cd /tmp
rm -rf nix-configurations
git clone https://github.com/ex1tium/nix-configurations.git
cd nix-configurations

echo "🔧 Creating correct hardware configuration..."
cat > /tmp/hardware-configuration.nix << 'EOF'
# Hardware configuration with correct UUIDs
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/d9604f3f-c714-479d-9e7c-3c4131fd5271";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" "noatime" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/C6B3-5712";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/d9604f3f-c714-479d-9e7c-3c4131fd5271";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" "noatime" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/d9604f3f-c714-479d-9e7c-3c4131fd5271";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" ];
    };

  fileSystems."/.snapshots" =
    { device = "/dev/disk/by-uuid/d9604f3f-c714-479d-9e7c-3c4131fd5271";
      fsType = "btrfs";
      options = [ "subvol=snapshots" "compress=zstd" "noatime" ];
    };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
EOF

# Copy the correct hardware configuration to both locations
echo "📝 Installing correct hardware configuration..."
sudo cp /tmp/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix
cp /tmp/hardware-configuration.nix machines/elara/hardware-configuration.nix

echo "🔨 Rebuilding system with correct configuration..."
sudo nixos-install --no-root-password --flake ".#elara" --root /mnt

echo
echo "✅ Boot fix completed!"
echo "🚀 You can now reboot and the system should boot successfully."
echo
echo "To reboot: sudo reboot"
