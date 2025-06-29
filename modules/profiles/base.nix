# Base Profile - Common foundation for all system profiles
# This profile provides the essential configuration that all machines need

{ config, lib, pkgs, globalConfig ? {}, ... }:

with lib;

let
  # Import centralized defaults
  defaults = import ../defaults.nix { inherit lib; };
in

{
  imports = [
    ../nixos
    ../features/locale-fi.nix
  ];

  # Base profile configuration using centralized defaults
  mySystem = {
    enable = true;

    # Basic system settings from centralized defaults with global config override
    hostname = mkDefault (globalConfig.defaultHostname or "nixos");
    user = mkDefault (globalConfig.defaultUser or defaults.system.defaultUser);
    timezone = mkDefault (globalConfig.defaultTimezone or defaults.system.timezone);
    locale = mkDefault (globalConfig.defaultLocale or defaults.system.locale);
    stateVersion = mkDefault (globalConfig.defaultStateVersion or defaults.system.stateVersion);

    # Base features - minimal set for all systems using centralized defaults
    features = {
      desktop = {
        enable = mkDefault defaults.features.desktop.enable;
        environment = mkDefault defaults.features.desktop.environment;
        displayManager = mkDefault defaults.features.desktop.displayManager;
        enableWayland = mkDefault defaults.features.desktop.enableWayland;
        enableX11 = mkDefault defaults.features.desktop.enableX11;
        enableRemoteDesktop = mkDefault defaults.features.desktop.enableRemoteDesktop;
      };

      development = {
        enable = mkDefault defaults.features.development.enable;
        languages = mkDefault defaults.features.development.languages;
        editors = mkDefault defaults.features.development.editors;
        enableContainers = mkDefault defaults.features.development.enableContainers;
        enableVirtualization = mkDefault defaults.features.development.enableVirtualization;
        enableDatabases = mkDefault defaults.features.development.enableDatabases;
      };

      virtualization = {
        enable = mkDefault defaults.features.virtualization.enable;
        enableDocker = mkDefault defaults.features.virtualization.enableDocker;
        enablePodman = mkDefault defaults.features.virtualization.enablePodman;
        enableLibvirt = mkDefault defaults.features.virtualization.enableLibvirt;
        enableVirtualbox = mkDefault defaults.features.virtualization.enableVirtualbox;
        enableWaydroid = mkDefault defaults.features.virtualization.enableWaydroid;
      };

      server = {
        enable = mkDefault defaults.features.server.enable;
        enableMonitoring = mkDefault defaults.features.server.enableMonitoring;
        enableBackup = mkDefault defaults.features.server.enableBackup;
        enableWebServer = mkDefault defaults.features.server.enableWebServer;
      };
    };

    # Base hardware configuration using centralized defaults
    hardware = {
      kernel = mkDefault defaults.hardware.kernel;
      enableVirtualization = mkDefault defaults.hardware.enableVirtualization;
      enableRemoteDesktop = mkDefault defaults.hardware.enableRemoteDesktop;
      gpu = mkDefault defaults.hardware.gpu;  # Now "auto" by default
      
      # Enhanced hardware detection enabled by default - auto-detects everything
      enable = mkDefault true;
      debug = mkDefault false;
    };
  };

  # Base system packages (using shared collections)
  environment.systemPackages =
    let
      packages = import ../packages/common.nix { inherit pkgs; };
    in
    packages.systemTools ++
    packages.cliTools ++
    packages.systemUtilities ++
    packages.networkTools ++
    packages.archiveTools ++
    packages.securityTools;

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
