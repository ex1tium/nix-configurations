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

    # Essential system packages (using shared collections)
    environment.systemPackages =
      let
        packages = import ../packages/common.nix { inherit pkgs; };
      in
      packages.systemTools ++
      packages.cliTools ++
      packages.systemUtilities ++
      packages.networkTools ++
      packages.archiveTools ++
      packages.securityTools ++
      [ pkgs.browsh ] ++  # Additional core-specific package
      optionals config.mySystem.features.desktop.enable [
        # Desktop-specific packages
        pkgs.pinentry-gtk2
        pkgs.xsel
        pkgs.xclip
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

    # Locale configuration is handled by locale-fi.nix module

    # Console configuration is handled by locale-fi.nix module

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
