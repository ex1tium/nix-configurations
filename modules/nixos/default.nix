# Modern NixOS Module System
# This file provides the main module interface with proper options and types

{ config, lib, globalConfig ? {}, finalFeatures ? {}, ... }:

with lib;

let
  # Import centralized defaults
  defaults = import ../defaults.nix { inherit lib; };
in

{
  # Import core foundation modules only
  imports = [
    ./core.nix
    ./users.nix
    ./networking.nix
    ./security.nix
    ./hardware-compatibility.nix  # Hardware compatibility detection and fixes
    ../validation.nix  # Comprehensive validation and error handling
  ];

  # Modern option definitions with proper types using centralized defaults
  options.mySystem = {
    enable = mkEnableOption "custom system configuration";

    hostname = mkOption {
      type = types.str;
      default = globalConfig.defaultHostname or "nixos";
      description = "System hostname";
      example = "my-machine";
    };

    user = mkOption {
      type = types.str;
      default = globalConfig.defaultUser or defaults.system.defaultUser;
      description = "Primary user account";
      example = "john";
    };

    timezone = mkOption {
      type = types.str;
      default = globalConfig.defaultTimezone or defaults.system.timezone;
      description = "System timezone";
      example = "Europe/Helsinki";
    };

    locale = mkOption {
      type = types.str;
      default = globalConfig.defaultLocale or defaults.system.locale;
      description = "System locale";
      example = "en_US.UTF-8";
    };

    stateVersion = mkOption {
      type = types.str;
      default = globalConfig.defaultStateVersion or defaults.system.stateVersion;
      description = "NixOS state version";
      example = "25.05";
    };

    features = mkOption {
      type = types.submodule {
        options = {
          desktop = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "desktop environment";
                environment = mkOption {
                  type = types.enum [ "plasma" "gnome" "xfce" "i3" ];
                  default = defaults.features.desktop.environment;
                  description = "Desktop environment to use";
                };
                lowSpec = mkEnableOption "low-spec optimizations for older hardware";
                enableWayland = mkOption {
                  type = types.bool;
                  default = defaults.features.desktop.enableWayland;
                  description = "Enable Wayland display server support";
                };
                enableX11 = mkOption {
                  type = types.bool;
                  default = defaults.features.desktop.enableX11;
                  description = "Enable X11 display server support";
                };
                displayManager = mkOption {
                  type = types.enum [ "sddm" "gdm" "lightdm" ];
                  default = defaults.features.desktop.displayManager;
                  description = "Display manager to use";
                };
                enableRemoteDesktop = mkEnableOption "remote desktop access";
              };
            };
            default = {};
            description = "Desktop environment configuration";
          };

          development = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "development tools";
                languages = mkOption {
                  type = types.listOf (types.enum [ "nodejs" "go" "python" "rust" "nix" "java" "cpp" ]);
                  default = defaults.features.development.languages;
                  description = "Programming languages to support";
                };
                editors = mkOption {
                  type = types.listOf (types.enum [ "vscode" "neovim" "vim" "emacs" ]);
                  default = defaults.features.development.editors;
                  description = "Text editors to install";
                };
                enableContainers = mkEnableOption "container development tools";
                enableVirtualization = mkEnableOption "virtualization for development";
                enableDatabases = mkEnableOption "database development tools";
              };
            };
            default = {};
            description = "Development environment configuration";
          };

          virtualization = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "virtualization support";
                enableDocker = mkEnableOption "Docker container runtime";
                enablePodman = mkEnableOption "Podman container runtime";
                enableLibvirt = mkEnableOption "libvirt/KVM virtualization";
                enableVirtualbox = mkEnableOption "VirtualBox virtualization";
                enableWaydroid = mkEnableOption "Waydroid Android emulation";
              };
            };
            default = {};
            description = "Virtualization and container configuration";
          };

          server = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "server-specific features";
                enableMonitoring = mkEnableOption "system monitoring tools";
                enableBackup = mkEnableOption "backup solutions";
                enableWebServer = mkEnableOption "web server capabilities";
              };
            };
            default = {};
            description = "Server-specific configuration";
          };

          btrfsSnapshots = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "BTRFS snapshots with Snapper";
                autoSnapshots = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Enable automatic timeline snapshots";
                };
                rootConfig = {
                  enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable snapshots for root filesystem (@root subvolume)";
                  };
                  timelineCreate = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Create automatic timeline snapshots for root";
                  };
                  timelineCleanup = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable automatic cleanup of old root snapshots";
                  };
                  retentionPolicy = mkOption {
                    type = types.attrs;
                    default = {
                      TIMELINE_MIN_AGE = "1800";      # 30 minutes
                      TIMELINE_LIMIT_HOURLY = "10";   # Keep 10 hourly snapshots
                      TIMELINE_LIMIT_DAILY = "10";    # Keep 10 daily snapshots
                      TIMELINE_LIMIT_WEEKLY = "0";    # No weekly snapshots
                      TIMELINE_LIMIT_MONTHLY = "0";   # No monthly snapshots
                      TIMELINE_LIMIT_YEARLY = "0";    # No yearly snapshots
                    };
                    description = "Retention policy for root snapshots";
                  };
                };
                homeConfig = {
                  enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable snapshots for home filesystem (@home subvolume)";
                  };
                  timelineCreate = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Create automatic timeline snapshots for home";
                  };
                  timelineCleanup = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable automatic cleanup of old home snapshots";
                  };
                  retentionPolicy = mkOption {
                    type = types.attrs;
                    default = {
                      TIMELINE_MIN_AGE = "1800";      # 30 minutes
                      TIMELINE_LIMIT_HOURLY = "24";   # Keep 24 hourly snapshots (1 day)
                      TIMELINE_LIMIT_DAILY = "7";     # Keep 7 daily snapshots (1 week)
                      TIMELINE_LIMIT_WEEKLY = "4";    # Keep 4 weekly snapshots (1 month)
                      TIMELINE_LIMIT_MONTHLY = "3";   # Keep 3 monthly snapshots
                      TIMELINE_LIMIT_YEARLY = "0";    # No yearly snapshots
                    };
                    description = "Retention policy for home snapshots";
                  };
                };
              };
            };
            default = {};
            description = "BTRFS snapshots configuration";
          };
        };
      };
      default = if finalFeatures != {} then finalFeatures else {};
      description = "System features configuration";
    };

    hardware = mkOption {
      type = types.submodule {
        options = {
          kernel = mkOption {
            type = types.enum [ "stable" "latest" "lts" ];
            default = defaults.hardware.kernel;
            description = "Kernel version to use";
          };
          enableVirtualization = mkEnableOption "hardware virtualization support";
          enableRemoteDesktop = mkEnableOption "remote desktop hardware acceleration";
          # gpu option is now defined by the enhanced hardware detection module
        };
      };
      default = {};
      description = "Hardware-specific configuration";
    };
  };

  # Configuration implementation
  config = mkIf config.mySystem.enable {
    # The actual configuration is handled by the imported modules
    # This ensures proper module composition and avoids conflicts

    # Validation is now handled by the comprehensive validation module (../validation.nix)
  };
}
