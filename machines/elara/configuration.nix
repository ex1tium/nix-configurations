{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/common.nix
    ../../modules/system/networking.nix
    ../../modules/system/desktop.nix
  ];

  # Machine-specific settings.
  networking.hostName = "elara";

  # User accounts.
  users.users.ex1tium = {
    isNormalUser = true;
    description = "ex1tium";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
    home = "/home/ex1tium";
  };

  # Packages specific to this machine.
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    tree
    spice-vdagent
    xorg.xf86videoqxl
    xorg.xrandr
    xsel
    xclip
  ];

  # Enable QEMU Guest Agent and SPICE services.
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # XRDP for remote desktop.
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11"; # Use X11 with KDE Plasma.
  };

  # Browser installation.
  programs.firefox.enable = true;
}
