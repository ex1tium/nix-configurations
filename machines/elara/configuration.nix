# Configuration for the 'elara' machine
# This file contains machine-specific settings and configurations

# The function takes three arguments:
# - config: The current configuration
# - pkgs: The nixpkgs package set
# - ...: Other arguments that might be passed
{ config, pkgs, ... }:

{
  # Import other configuration modules
  imports = [
    # Hardware-specific configuration (automatically generated)
    ./hardware-configuration.nix
    # Common system settings shared across machines
    ../../modules/system/common.nix
    # Network configuration settings
    ../../modules/system/networking.nix
    # Desktop environment settings
    ../../modules/system/desktop.nix
  ];

  # Nix-specific settings
  nix.settings.cores = 4; # Number of cores to use for building

  # Basic network configuration
  networking.hostName = "elara"; # Set the machine's hostname

  # User account configuration
  users.users.ex1tium = {
    isNormalUser = true;     # This is a regular user account (not system)
    description = "ex1tium"; # Full name or description
    extraGroups = [
      "networkmanager"       # Allows network management
      "wheel"               # Enables sudo access
    ];
    group = "users";        # Primary group
    # User-specific packages
    packages = with pkgs; [
      kdePackages.kate      # KDE text editor
    ];
    home = "/home/ex1tium"; # Home directory location
  };

  # Configure home-manager for the user
  home-manager.users.ex1tium = { pkgs, ... }: {
    imports = [
      ../../modules/home/common-home.nix
    ];
    home.stateVersion = "23.11";  # Please read the comment in 'home.nix' about this value
  };

  # System-wide packages specific to this machine
  environment.systemPackages = with pkgs; [
    git                     # Version control
    vim                     # Text editor
    wget                    # File download utility
    tree                    # Directory listing tool
    spice-vdagent          # SPICE guest agent for VMs
    xorg.xf86videoqxl      # QXL video driver for VMs
    xorg.xrandr            # Screen resolution management
    xsel                   # X selection tool
    xclip                  # Clipboard tool
  ];

  # Virtual Machine Services
  # Enable QEMU guest agent for better VM integration
  services.qemuGuest.enable = true;
  # Enable SPICE agent for clipboard sharing and resolution handling
  services.spice-vdagentd.enable = true;

  # Remote Desktop Configuration
  services.xrdp = {
    enable = true;
    # Use KDE Plasma with X11 as the default session
    defaultWindowManager = "startplasma-x11";
  };

  # Browser Configuration
  programs.firefox.enable = true; # Install and enable Firefox

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
