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
  # This module implements BTRFS snapshots functionality
  # Options are declared in modules/nixos/default.nix

  config = mkIf cfg.enable {
    # Ensure BTRFS tools are available
    environment.systemPackages = with pkgs; [
      btrfs-progs
      snapper
      snapper-gui  # Optional GUI for snapshot management
    ];

    # Configure Snapper service
    services.snapper = {
      # Snapper configurations for each subvolume
      configs = mkMerge [
        # Root filesystem snapshots (@root subvolume)
        (mkIf cfg.rootConfig.enable {
          root = {
            subvolume = "/";
            extraConfig = ''
              ALLOW_USERS="${primaryUser}"
              ALLOW_GROUPS="wheel"
              TIMELINE_CREATE="${if cfg.rootConfig.timelineCreate then "yes" else "no"}"
              TIMELINE_CLEANUP="${if cfg.rootConfig.timelineCleanup then "yes" else "no"}"
              TIMELINE_MIN_AGE="${cfg.rootConfig.retentionPolicy.TIMELINE_MIN_AGE}"
              TIMELINE_LIMIT_HOURLY="${cfg.rootConfig.retentionPolicy.TIMELINE_LIMIT_HOURLY}"
              TIMELINE_LIMIT_DAILY="${cfg.rootConfig.retentionPolicy.TIMELINE_LIMIT_DAILY}"
              TIMELINE_LIMIT_WEEKLY="${cfg.rootConfig.retentionPolicy.TIMELINE_LIMIT_WEEKLY}"
              TIMELINE_LIMIT_MONTHLY="${cfg.rootConfig.retentionPolicy.TIMELINE_LIMIT_MONTHLY}"
              TIMELINE_LIMIT_YEARLY="${cfg.rootConfig.retentionPolicy.TIMELINE_LIMIT_YEARLY}"
            '';
          };
        })
        
        # Home filesystem snapshots (@home subvolume)
        (mkIf cfg.homeConfig.enable {
          home = {
            subvolume = "/home";
            extraConfig = ''
              ALLOW_USERS="${primaryUser}"
              ALLOW_GROUPS="wheel"
              TIMELINE_CREATE="${if cfg.homeConfig.timelineCreate then "yes" else "no"}"
              TIMELINE_CLEANUP="${if cfg.homeConfig.timelineCleanup then "yes" else "no"}"
              TIMELINE_MIN_AGE="${cfg.homeConfig.retentionPolicy.TIMELINE_MIN_AGE}"
              TIMELINE_LIMIT_HOURLY="${cfg.homeConfig.retentionPolicy.TIMELINE_LIMIT_HOURLY}"
              TIMELINE_LIMIT_DAILY="${cfg.homeConfig.retentionPolicy.TIMELINE_LIMIT_DAILY}"
              TIMELINE_LIMIT_WEEKLY="${cfg.homeConfig.retentionPolicy.TIMELINE_LIMIT_WEEKLY}"
              TIMELINE_LIMIT_MONTHLY="${cfg.homeConfig.retentionPolicy.TIMELINE_LIMIT_MONTHLY}"
              TIMELINE_LIMIT_YEARLY="${cfg.homeConfig.retentionPolicy.TIMELINE_LIMIT_YEARLY}"
            '';
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
