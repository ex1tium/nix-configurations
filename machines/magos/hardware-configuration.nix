# Hardware configuration for 'magos' machine
# Generated from live-cd setup with manual adjustments for dual-boot Windows 11 + NixOS
# Device: 128 GB UFS/eUFS storage with Btrfs subvolumes
# CPU: Intel (with microcode updates)

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # UFS/eUFS storage device support
  boot.initrd.availableKernelModules = [ "ufshcd_pci" "xhci_pci" "usb_storage" "sd_mod" "i915" ];
  boot.initrd.kernelModules = [ "i915" ]; # Load Intel GPU driver early for display
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Root filesystem: Btrfs on /dev/sdb6 with @ subvolume
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/0c1e6e2c-9459-48b6-915a-9d60b1100b88";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd" "ssd" "noatime" "space_cache=v2" "autodefrag" ];
    };

  # Nix store: separate subvolume with NOCOW for reduced write amplification
  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/0c1e6e2c-9459-48b6-915a-9d60b1100b88";
      fsType = "btrfs";
      options = [ "subvol=@nix" "ssd" "noatime" ];
    };

  # Home directory: separate subvolume for better snapshot management
  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/0c1e6e2c-9459-48b6-915a-9d60b1100b88";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd" "ssd" "noatime" ];
    };

  # System logs: separate subvolume to prevent log growth from filling root
  fileSystems."/var/log" =
    { device = "/dev/disk/by-uuid/0c1e6e2c-9459-48b6-915a-9d60b1100b88";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd" "ssd" "noatime" ];
    };

  # Package cache: separate subvolume for better isolation
  fileSystems."/var/cache" =
    { device = "/dev/disk/by-uuid/0c1e6e2c-9459-48b6-915a-9d60b1100b88";
      fsType = "btrfs";
      options = [ "subvol=@cache" "compress=zstd" "ssd" "noatime" ];
    };

  # Snapshots: separate subvolume for Snapper management
  fileSystems."/.snapshots" =
    { device = "/dev/disk/by-uuid/0c1e6e2c-9459-48b6-915a-9d60b1100b88";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd" "ssd" "noatime" ];
    };

  # EFI System Partition: shared with Windows (vfat)
  # IMPORTANT: systemd-boot expects this at /boot, not /boot/efi
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/52FD-472F";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  # Swap: dedicated partition for zram overflow
  swapDevices =
    [ { device = "/dev/disk/by-uuid/3ca2cc1f-8c38-4942-863e-02784c17b5e7"; }
    ];

  # Networking configuration
  networking.useDHCP = lib.mkDefault true;

  # Platform-specific settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

