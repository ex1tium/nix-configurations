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
          gpu = mkOption {
            type = types.enum [ "intel" "amd" "nvidia" "none" ];
            default = defaults.hardware.gpu;
            description = "GPU type for driver optimization";
          };
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

    # Assertions to validate configuration
    assertions = [
      {
        assertion = config.mySystem.user != "";
        message = "mySystem.user must be set to a non-empty string";
      }
      {
        assertion = config.mySystem.hostname != "";
        message = "mySystem.hostname must be set to a non-empty string";
      }
      {
        assertion = !(config.mySystem.features.virtualization.enableVirtualbox && config.mySystem.features.virtualization.enableLibvirt);
        message = "VirtualBox and libvirt/KVM cannot be enabled simultaneously due to conflicts";
      }
      {
        assertion = config.mySystem.features.desktop.enable -> (config.mySystem.features.desktop.environment != "");
        message = "Desktop environment must be specified when desktop features are enabled";
      }
    ];

    # Warnings for common configuration issues
    warnings = []
      ++ optional (config.mySystem.features.development.enable && !config.mySystem.features.virtualization.enableDocker && !config.mySystem.features.virtualization.enablePodman)
         "Development features are enabled but no container runtime is configured"
      ++ optional (config.mySystem.features.desktop.enable && !config.mySystem.features.desktop.enableWayland && !config.mySystem.features.desktop.enableX11)
         "Desktop is enabled but neither Wayland nor X11 is enabled"
      ++ optional (config.mySystem.hardware.kernel == "latest" && !config.mySystem.features.development.enable)
         "Latest kernel is selected but development features are disabled - consider using 'stable' kernel for better stability";
  };
}
