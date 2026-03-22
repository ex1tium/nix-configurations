# Rescue CLI Profile - Minimal recovery environment for an installed machine
# Target: Low-overhead maintenance, boot repair, and remote recovery tasks

{ lib, pkgs, ... }:

with lib;

{
  imports = [
    ./base.nix
  ];

  mySystem = {
    hostname = mkDefault "rescue-cli";

    features = {
      desktop = {
        enable = mkForce false;
        enableWayland = mkForce false;
        enableX11 = mkForce false;
        enableRemoteDesktop = mkForce false;
      };

      development = {
        enable = mkForce false;
        languages = mkForce [ "nix" ];
        editors = mkForce [ "vim" ];
        enableContainers = mkForce false;
        enableVirtualization = mkForce false;
        enableDatabases = mkForce false;
      };

      virtualization = {
        enable = mkForce false;
        enableDocker = mkForce false;
        enablePodman = mkForce false;
        enableLibvirt = mkForce false;
        enableVirtualbox = mkForce false;
        enableWaydroid = mkForce false;
      };

      server = {
        enable = mkForce false;
        enableMonitoring = mkForce false;
        enableBackup = mkForce false;
        enableWebServer = mkForce false;
      };
    };

    hardware = {
      kernel = mkDefault "stable";
      enableVirtualization = mkForce false;
      enableRemoteDesktop = mkForce false;
      thunderbolt.enable = mkDefault true;
    };
  };

  networking.networkmanager.enable = mkDefault true;

  services.openssh.enable = mkForce true;

  environment.systemPackages = with pkgs; [
    gitFull
    git-lfs
    gh
    btrfs-progs
    cryptsetup
    pciutils
    usbutils
    efibootmgr
  ];
}