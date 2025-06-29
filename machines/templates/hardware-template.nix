# Template Hardware Configuration
# This is a placeholder used for development builds when no actual hardware-configuration.nix exists
# During actual installation, this will be replaced by nixos-generate-config output

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Template boot configuration - will be replaced during installation
  boot = {
    initrd = {
      availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    
    # Template loader configuration
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
    };
  };

  # Template filesystem configuration - will be replaced during installation
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" "noatime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" "noatime" ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" ];
    };
  };

  # Template swap configuration
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];

  # Template hardware settings
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = lib.mkDefault true;
  };

  # Template networking
  networking.useDHCP = lib.mkDefault true;

  # Template system settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Warning comment for development builds
  warnings = [
    ''
      This system is using a template hardware configuration.
      For actual deployment, run nixos-generate-config to create proper hardware-configuration.nix
      or use the provided installation scripts which handle this automatically.
    ''
  ];
}
