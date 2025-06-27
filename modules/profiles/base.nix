# Base Profile - Common foundation for all system profiles
# This profile provides the essential configuration that all machines need

{ config, lib, pkgs, globalConfig ? {}, ... }:

with lib;

{
  imports = [
    ../nixos
  ];

  # Base profile configuration
  mySystem = {
    enable = true;
    
    # Basic system settings from global config
    hostname = mkDefault (globalConfig.defaultHostname or "nixos");
    user = mkDefault (globalConfig.defaultUser or "user");
    timezone = mkDefault (globalConfig.defaultTimezone or "UTC");
    locale = mkDefault (globalConfig.defaultLocale or "en_US.UTF-8");
    stateVersion = mkDefault (globalConfig.defaultStateVersion or "24.11");

    # Base features - minimal set for all systems
    features = {
      desktop = {
        enable = mkDefault false;
        environment = mkDefault "plasma";
        displayManager = mkDefault "sddm";
        enableWayland = mkDefault true;
        enableX11 = mkDefault true;
        enableRemoteDesktop = mkDefault false;
      };

      development = {
        enable = mkDefault false;
        languages = mkDefault [ "nix" ];
        editors = mkDefault [ "vim" ];
        enableContainers = mkDefault false;
        enableVirtualization = mkDefault false;
        enableDatabases = mkDefault false;
      };

      virtualization = {
        enable = mkDefault false;
        enableDocker = mkDefault false;
        enablePodman = mkDefault false;
        enableLibvirt = mkDefault false;
        enableVirtualbox = mkDefault false;
        enableWaydroid = mkDefault false;
      };

      server = {
        enable = mkDefault false;
        enableMonitoring = mkDefault false;
        enableBackup = mkDefault false;
        enableWebServer = mkDefault false;
      };
    };

    # Base hardware configuration
    hardware = {
      kernel = mkDefault "stable";
      enableVirtualization = mkDefault false;
      enableRemoteDesktop = mkDefault false;
      gpu = mkDefault "none";
    };
  };

  # Base system packages (minimal set)
  environment.systemPackages = with pkgs; [
    # Essential system tools
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
    
    # System utilities
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
  ];

  # Base services configuration
  services = {
    # SSH is enabled by default for remote management
    openssh = {
      enable = mkDefault true;
      settings = {
        PasswordAuthentication = mkDefault true;
        PermitRootLogin = mkDefault "no";
        X11Forwarding = mkDefault false;
        AllowUsers = mkDefault [ config.mySystem.user ];
      };
      openFirewall = mkDefault true;
    };

    # Time synchronization
    timesyncd.enable = mkDefault true;

    # DNS resolution
    resolved.enable = mkDefault true;
  };

  # Base networking configuration
  networking = {
    # Hostname is set by core module
    
    # Basic firewall
    firewall = {
      enable = mkDefault true;
      allowPing = mkDefault true;
      allowedTCPPorts = mkDefault [ 22 ]; # SSH
    };

    # Disable IPv6 by default (can be enabled per machine)
    enableIPv6 = mkDefault false;
  };

  # User configuration is handled by users.nix module

  # Program configuration is handled by users.nix module

  # Environment, documentation, and security configuration are handled by core modules

  # Hardware configuration is handled by core.nix module

  # Boot configuration is handled by core.nix module

  # Nix configuration is handled by core.nix module

  # Package management and system maintenance are handled by core.nix module
}
