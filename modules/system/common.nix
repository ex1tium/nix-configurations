# Common system configuration module
# This module contains settings that are shared across all machines

{ config, pkgs, ... }:
{
  # Boot Configuration
  boot.loader = {
    # Use systemd-boot as the bootloader
    systemd-boot.enable = true;
    # Allow modification of EFI boot variables
    efi.canTouchEfiVariables = true;
    # Limit the number of generations kept in the boot menu
    systemd-boot.configurationLimit = 5;
  };

  # Automatic System Maintenance
  nix.gc = {
    automatic = true;        # Enable automatic garbage collection
    dates = "weekly";       # Run GC once per week
    options = "--delete-older-than 7d";  # Remove generations older than 7 days
  };

  # Time and Locale Settings
  time.timeZone = "Europe/Helsinki";  # Set system timezone

  # Internationalization Settings
  i18n = {
    defaultLocale = "en_US.UTF-8";  # Default system language
    # Regional format settings for Finland
    extraLocaleSettings = {
      LC_ADDRESS = "fi_FI.UTF-8";        # Address format
      LC_IDENTIFICATION = "fi_FI.UTF-8";  # User information
      LC_MEASUREMENT = "fi_FI.UTF-8";     # Measurement units
      LC_MONETARY = "fi_FI.UTF-8";        # Currency format
      LC_NAME = "fi_FI.UTF-8";           # Name format
      LC_NUMERIC = "fi_FI.UTF-8";        # Number format
      LC_PAPER = "fi_FI.UTF-8";          # Paper size
      LC_TELEPHONE = "fi_FI.UTF-8";      # Phone number format
      LC_TIME = "fi_FI.UTF-8";           # Time format
    };
  };

  # GPG Configuration
  programs.gnupg = {
    agent = {
      enable = true;        # Enable GPG agent
      enableSSHSupport = true;  # Use GPG agent for SSH
    };
    # Enable GPG agent socket
    package = pkgs.gnupg;   # Use the latest stable GnuPG
  };

  # Install GPG-related packages
  environment.systemPackages = with pkgs; [
    gnupg              # Main GPG package
    pinentry          # For password entry
    pinentry-gtk2     # GTK-based pinentry
    zsh               # ZSH shell
  ];

  # Set ZSH as an available login shell
  environment.shells = with pkgs; [ zsh ];
  users.defaultUserShell = pkgs.zsh;

  # Audio Configuration
  # Disable PulseAudio in favor of PipeWire
  hardware.pulseaudio.enable = false;
  # Enable RealtimeKit for better audio performance
  security.rtkit.enable = true;
  # PipeWire Configuration
  services.pipewire = {
    enable = true;           # Enable PipeWire audio server
    alsa.enable = true;     # ALSA support
    alsa.support32Bit = true; # 32-bit ALSA support
    pulse.enable = true;    # PulseAudio compatibility
  };

  # Package Management
  nixpkgs.config.allowUnfree = true;  # Allow proprietary packages

  # System State Version
  # This value determines how to do future updates
  # DO NOT CHANGE THIS after setting it initially!
  system.stateVersion = "24.11";

  # Nix Features
  nix.settings.experimental-features = [
    "nix-command"  # Enable new nix command-line interface
    "flakes"       # Enable flakes feature for better reproducibility
  ];
}
