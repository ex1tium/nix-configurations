# BTRFS Snapshots Configuration Module
# Provides automated snapshot management using Snapper with optimal BTRFS layout
# Supports the @root, @home, @nix, @snapshots subvolume structure

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mySystem.features.btrfsSnapshots;
  primaryUser = config.mySystem.user;
in

{
  options.mySystem.features.btrfsSnapshots = {
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

    excludePatterns = mkOption {
      type = types.listOf types.str;
      default = [
        # Temporary files and caches
        "/tmp/*"
        "/var/tmp/*"
        "/var/cache/*"
        "/var/log/*"
        
        # User caches and temporary data
        "/home/*/.cache/*"
        "/home/*/.local/share/Trash/*"
        "/home/*/.thumbnails/*"
        "/home/*/Downloads/*"
        
        # Development artifacts
        "/home/*/node_modules/*"
        "/home/*/.npm/*"
        "/home/*/.cargo/registry/*"
        "/home/*/.rustup/*"
        
        # Browser caches
        "/home/*/.mozilla/firefox/*/Cache/*"
        "/home/*/.config/google-chrome/*/Cache/*"
        "/home/*/.config/BraveSoftware/*/Cache/*"
      ];
      description = "Patterns to exclude from snapshots";
    };
  };

  config = mkIf cfg.enable {
    # Ensure BTRFS tools are available
    environment.systemPackages = with pkgs; [
      btrfs-progs
      snapper
      snapper-gui  # Optional GUI for snapshot management
    ];

    # Configure Snapper service
    services.snapper = {
      enable = true;
      
      # Snapper configurations for each subvolume
      configs = mkMerge [
        # Root filesystem snapshots (@root subvolume)
        (mkIf cfg.rootConfig.enable {
          root = {
            SUBVOLUME = "/";
            ALLOW_USERS = [ primaryUser ];
            ALLOW_GROUPS = [ "wheel" ];
            
            # Timeline snapshots
            TIMELINE_CREATE = cfg.rootConfig.timelineCreate;
            TIMELINE_CLEANUP = cfg.rootConfig.timelineCleanup;
            
            # Retention policy
            inherit (cfg.rootConfig.retentionPolicy)
              TIMELINE_MIN_AGE
              TIMELINE_LIMIT_HOURLY
              TIMELINE_LIMIT_DAILY
              TIMELINE_LIMIT_WEEKLY
              TIMELINE_LIMIT_MONTHLY
              TIMELINE_LIMIT_YEARLY;
            
            # Exclude patterns
            EXCLUDE_PATTERNS = concatStringsSep " " cfg.excludePatterns;
          };
        })
        
        # Home filesystem snapshots (@home subvolume)
        (mkIf cfg.homeConfig.enable {
          home = {
            SUBVOLUME = "/home";
            ALLOW_USERS = [ primaryUser ];
            ALLOW_GROUPS = [ "wheel" ];
            
            # Timeline snapshots
            TIMELINE_CREATE = cfg.homeConfig.timelineCreate;
            TIMELINE_CLEANUP = cfg.homeConfig.timelineCleanup;
            
            # Retention policy
            inherit (cfg.homeConfig.retentionPolicy)
              TIMELINE_MIN_AGE
              TIMELINE_LIMIT_HOURLY
              TIMELINE_LIMIT_DAILY
              TIMELINE_LIMIT_WEEKLY
              TIMELINE_LIMIT_MONTHLY
              TIMELINE_LIMIT_YEARLY;
            
            # Exclude patterns (focused on user data)
            EXCLUDE_PATTERNS = concatStringsSep " " (filter (p: hasInfix "/home/" p) cfg.excludePatterns);
          };
        })
      ];
    };

    # Add user to snapper group for snapshot management
    users.users.${primaryUser}.extraGroups = [ "snapper" ];

    # Create systemd timer for automatic snapshots if enabled
    systemd.timers = mkIf cfg.autoSnapshots {
      snapper-timeline = {
        description = "Timeline snapshots";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };
      
      snapper-cleanup = {
        description = "Cleanup old snapshots";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
    };

    # Systemd services for snapshot management
    systemd.services = mkIf cfg.autoSnapshots {
      snapper-timeline = {
        description = "Timeline snapshots";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.snapper}/bin/snapper --config root create --type timeline";
          User = "root";
        };
      };
      
      snapper-cleanup = {
        description = "Cleanup old snapshots";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = [
            "${pkgs.snapper}/bin/snapper --config root cleanup timeline"
            "${pkgs.snapper}/bin/snapper --config home cleanup timeline"
          ];
          User = "root";
        };
      };
    };

    # Warnings for optimal configuration
    warnings = []
      ++ optional (!config.boot.supportedFilesystems.btrfs or false)
         "BTRFS snapshots enabled but BTRFS is not in boot.supportedFilesystems. Add 'btrfs' to supported filesystems."
      ++ optional (cfg.enable && !config.services.snapper.enable)
         "BTRFS snapshots feature enabled but Snapper service is disabled. This is unusual."
      ++ optional (cfg.autoSnapshots && cfg.rootConfig.enable && !cfg.rootConfig.timelineCreate)
         "Automatic snapshots enabled but timeline creation is disabled for root. Consider enabling TIMELINE_CREATE."
      ++ optional (cfg.autoSnapshots && cfg.homeConfig.enable && !cfg.homeConfig.timelineCreate)
         "Automatic snapshots enabled but timeline creation is disabled for home. Consider enabling TIMELINE_CREATE.";

    # Assertions for configuration validation
    assertions = [
      {
        assertion = cfg.enable -> (config.fileSystems."/".fsType == "btrfs");
        message = "BTRFS snapshots require the root filesystem to be BTRFS. Current root fsType: ${config.fileSystems."/".fsType or "unknown"}";
      }
      {
        assertion = cfg.homeConfig.enable -> (config.fileSystems."/home".fsType or "btrfs" == "btrfs");
        message = "Home snapshots enabled but /home is not on BTRFS filesystem.";
      }
      {
        assertion = primaryUser != "";
        message = "BTRFS snapshots require mySystem.user to be set to configure snapshot permissions.";
      }
    ];
  };
}
