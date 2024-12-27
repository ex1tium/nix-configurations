# Desktop Environment Configuration Module
# This module configures the graphical environment including
# display server, desktop environment, and keyboard layouts

{ config, pkgs, ... }:
{
  # X11 and Desktop Environment Configuration
  services = {
    # X11 Display Server
    xserver = {
      enable = true;      # Enable the X11 display server
      
      # Keyboard Layout Configuration for X11
      xkb = {
        layout = "fi";    # Use Finnish keyboard layout
        variant = "";     # No special variant
      };
    };

    # Display Manager Configuration
    displayManager = {
      sddm.enable = true;  # Enable SDDM login manager
                          # SDDM is the recommended display manager for KDE
    };

    # Desktop Environment
    desktopManager = {
      plasma6.enable = true;  # Enable KDE Plasma 6
                             # Modern, feature-rich desktop environment
    };
  };

  # Console (TTY) Configuration
  console = {
    keyMap = "fi";  # Use Finnish keyboard layout in virtual consoles
                   # This affects keyboard layout before X11 starts
  };
}
