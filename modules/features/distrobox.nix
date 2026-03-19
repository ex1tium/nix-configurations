# Distrobox Feature Module
# Minimal container workflow using Podman + Distrobox without the full virtualization stack

{ config, lib, pkgs, ... }:

with lib;

{
  options.mySystem.features.distrobox = {
    enable = mkEnableOption "Podman + Distrobox environment";
  };

  config = mkIf config.mySystem.features.distrobox.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = mkDefault true;
        dates = mkDefault "weekly";
        flags = [ "--all" "--volumes" ];
      };
    };

    environment.systemPackages = with pkgs; [
      podman
      distrobox
    ];

    users.users.${config.mySystem.user}.extraGroups = [
      "podman"
    ];

    users.groups.podman = {};

    environment.sessionVariables = {
      CONTAINER_RUNTIME = "podman";
      DOCKER_HOST = "unix:///run/podman/podman.sock";
    };

    home-manager.users.${config.mySystem.user} = {
      programs.distrobox = {
        enable = true;
        enableSystemdUnit = true;
        containers = {
          fedora-toolbox = {
            image = "registry.fedoraproject.org/fedora-toolbox:43";
          };
          ubuntu-toolbox = {
            image = "ubuntu:24.04";
          };
        };
      };
    };

    programs.zsh.shellAliases = {
      db = "distrobox";
      dba = "distrobox assemble";
      dbl = "distrobox list";
      dbi = "distrobox enter";
      p = "podman";
      pps = "podman ps";
      pi = "podman images";
    };
  };
}
