# Core NixOS Module
# Essential system configuration that applies to all machines

{ config, lib, pkgs, globalConfig ? {}, ... }:

with lib;

{
  # Core system configuration
  config = mkIf config.mySystem.enable {
    # Basic system properties
    networking.hostName = mkDefault config.mySystem.hostname;
    time.timeZone = mkDefault config.mySystem.timezone;
    i18n.defaultLocale = mkDefault config.mySystem.locale;
    system.stateVersion = mkDefault config.mySystem.stateVersion;

    # Essential Nix configuration
    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
        trusted-users = [ "root" "@wheel" ];
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
      package = pkgs.nixVersions.latest;
      
      # Automatic garbage collection
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };

    # Boot configuration
    boot = {
      loader = {
        systemd-boot.enable = mkDefault true;
        efi.canTouchEfiVariables = mkDefault true;
        systemd-boot.configurationLimit = mkDefault 10;
      };
      
      # Kernel parameters for better performance and security
      kernelParams = [
        "quiet"
        "loglevel=3"
        "systemd.show_status=auto"
        "rd.udev.log_level=3"
      ];
      
      # Enable firmware updates
      kernelPackages = mkDefault pkgs.linuxPackages;
    };

    # Hardware support
    hardware = {
      enableRedistributableFirmware = mkDefault true;
      enableAllFirmware = mkDefault false; # Only enable if needed
    };

    # Essential system packages
    environment.systemPackages = with pkgs; [
      # Core utilities
      vim
      nano
      git
      curl
      wget
      tree
      file
      which

      # Modern CLI tools
      bat
      eza
      fd
      ripgrep
      fzf
      zoxide
      htop
      btop
      browsh

      # System tools
      lsof
      psmisc
      procps
      util-linux

      # Network tools
      inetutils
      dnsutils

      # Archive tools
      zip
      unzip
      p7zip

      # Security tools
      gnupg
      pinentry
    ] ++ optionals config.mySystem.features.desktop.enable [
      # Desktop-specific packages
      pinentry-gtk2
      xsel
      xclip
    ];

    # Environment variables
    environment.variables = {
      EDITOR = mkDefault "nano";
      VISUAL = mkDefault "nano";
      PAGER = mkDefault "less";
    };

    # Shell configuration
    programs.zsh.enable = mkDefault true;
    environment.shells = with pkgs; [ bash zsh ];
    users.defaultUserShell = mkDefault pkgs.zsh;

    # Locale settings
    i18n.extraLocaleSettings = mkIf (config.mySystem.locale == "en_US.UTF-8") {
      LC_ADDRESS = mkDefault "fi_FI.UTF-8";
      LC_IDENTIFICATION = mkDefault "fi_FI.UTF-8";
      LC_MEASUREMENT = mkDefault "fi_FI.UTF-8";
      LC_MONETARY = mkDefault "fi_FI.UTF-8";
      LC_NAME = mkDefault "fi_FI.UTF-8";
      LC_NUMERIC = mkDefault "fi_FI.UTF-8";
      LC_PAPER = mkDefault "fi_FI.UTF-8";
      LC_TELEPHONE = mkDefault "fi_FI.UTF-8";
      LC_TIME = mkDefault "fi_FI.UTF-8";
    };

    # Console configuration
    console = {
      keyMap = mkDefault "us";
      font = mkDefault "Lat2-Terminus16";
    };

    # Package management
    nixpkgs.config = {
      allowUnfree = true;
      allowBroken = false;
      allowUnsupportedSystem = false;
    };

    # System maintenance
    system.autoUpgrade = {
      enable = mkDefault false; # Disabled by default, enable per machine
      dates = mkDefault "04:00";
      allowReboot = mkDefault false;
    };

    # Audio configuration is handled by feature modules
    # Desktop systems: configured in modules/features/desktop.nix
    # Server systems: audio disabled by default

    # Documentation
    documentation = {
      enable = mkDefault true;
      nixos.enable = mkDefault true;
      man.enable = mkDefault true;
      info.enable = mkDefault false;
      doc.enable = mkDefault false;
    };
  };
}
