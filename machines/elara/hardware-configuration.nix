# DO NOT USE IN PRODUCTION. ALWAYS GENERATE NEW HARDWARE CONFIGURATION DURING INSTALLATION AND USE IT
# Hardware configuration for elara (VM)
# This is a template configuration for VMs - will be replaced by actual hardware detection
# Generated for use in QEMU/KVM virtual machines

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # VM-typical boot configuration
  boot.initrd.availableKernelModules = [ 
    "xhci_pci" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" 
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # VM-typical filesystem configuration
  # NOTE: These paths should match your actual VM disk setup
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/PLACEHOLDER-ROOT-UUID";  # Will be replaced during installation
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/PLACEHOLDER-BOOT-UUID";  # Will be replaced during installation  
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # VM swap configuration
  swapDevices = [
    { device = "/dev/disk/by-uuid/PLACEHOLDER-SWAP-UUID"; }  # Will be replaced during installation
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;

  # VM hardware settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  
  # VM-specific optimizations
  # Note: Hardware compatibility module will override these with proper detection
  virtualisation.vmware.guest.enable = lib.mkDefault false;
  virtualisation.virtualbox.guest.enable = lib.mkDefault false;
  
  # This is a placeholder - actual hardware detection happens via hardware compatibility module
  boot.kernelParams = lib.mkDefault [
    "quiet"
    "splash"
  ];
}
