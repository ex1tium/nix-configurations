{ lib, pkgs, ... }:

{
  system.nixos.tags = [ "rescue" "cli" ];

  mySystem.features.desktop = {
    enable = lib.mkForce false;
    enableWayland = lib.mkForce false;
    enableX11 = lib.mkForce false;
    enableRemoteDesktop = lib.mkForce false;
  };

  services.xserver.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;

  environment.systemPackages = lib.mkForce [
    pkgs.gitFull
    pkgs.git-lfs
    pkgs.gh
    pkgs.vim
    pkgs.curl
    pkgs.wget
    pkgs.pciutils
    pkgs.usbutils
    pkgs.btrfs-progs
    pkgs.cryptsetup
  ];
}