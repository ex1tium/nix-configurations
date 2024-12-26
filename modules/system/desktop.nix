{ config, pkgs, ... }:
{
  # Enable X11 and KDE Plasma.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Console and X11 keymap.
  console.keyMap = "fi";
  services.xserver.xkb = {
    layout = "fi";
    variant = "";
  };
}
