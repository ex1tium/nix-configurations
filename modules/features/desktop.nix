# Desktop Feature Module
# Implements desktop environment functionality when enabled

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./hardware/gpu.nix
    ./desktop/display-server.nix
    ./desktop/common.nix
    ./desktop/packages.nix
    ./desktop/plasma.nix
    ./desktop/xfce.nix
  ];
  config = mkIf config.mySystem.features.desktop.enable {
    # All X11/Wayland configuration is handled by display-server.nix
    # All desktop environment configuration is handled by specific DE modules
    # (plasma.nix, xfce.nix, etc.) based on mySystem.features.desktop.environment

    # XDG Portal configuration is handled by specific DE modules

    # Desktop Audio System - PipeWire (complete configuration)
    hardware.pulseaudio.enable = mkDefault false; # Disable PulseAudio
    security.rtkit.enable = mkDefault true; # RealtimeKit for better audio performance

    services.pipewire = {
      enable = mkDefault true;
      alsa.enable = mkDefault true;
      alsa.support32Bit = mkDefault true;
      pulse.enable = mkDefault true; # PulseAudio compatibility

      # Low-latency configuration for desktop use
      extraConfig.pipewire."92-low-latency" = {
        context.properties = {
          default.clock.rate = 48000;
          default.clock.quantum = 32;
          default.clock.min-quantum = 32;
          default.clock.max-quantum = 32;
        };
      };

      # Enable JACK support for desktop audio production
      jack.enable = true;
    };

    # Printing Support
    services.printing = {
      enable = mkDefault true;
      drivers = with pkgs; [
        gutenprint
        hplip
        epson-escpr
        canon-cups-ufr2
      ];
    };

    # Scanning Support
    hardware.sane = {
      enable = mkDefault true;
      extraBackends = with pkgs; [
        sane-airscan
        hplipWithPlugin
      ];
    };

    # Bluetooth
    hardware.bluetooth = {
      enable = mkDefault true;
      powerOnBoot = mkDefault true;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
    services.blueman.enable = mkDefault true;

    # Graphics configuration is handled by hardware/gpu.nix module
    # This ensures proper GPU driver selection based on mySystem.hardware.gpu setting

    # Fonts
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-emoji
        liberation_ttf
        dejavu_fonts
        fira-code
        fira-code-symbols
        jetbrains-mono
        (nerdfonts.override { 
          fonts = [ "FiraCode" "JetBrainsMono" "DroidSansMono" "Hack" ]; 
        })
        ubuntu_font_family
        roboto
        open-sans
      ];
      
      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = [ "Noto Serif" "Liberation Serif" ];
          sansSerif = [ "Noto Sans" "Liberation Sans" ];
          monospace = [ "FiraCode Nerd Font Mono" "JetBrains Mono" ];
          emoji = [ "Noto Color Emoji" ];
        };
        subpixel.rgba = "rgb";
        hinting = {
          enable = true;
          style = "slight";
        };
        antialias = true;
      };
    };

    # Desktop packages are provided by specific DE modules and common.nix

    # Desktop Services
    services = {
      flatpak.enable = mkDefault true;
      tumbler.enable = mkDefault true;
      locate = {
        enable = mkDefault true;
        package = pkgs.mlocate;
        localuser = null;
      };
      upower.enable = mkDefault true;
      udisks2.enable = mkDefault true;
      fwupd.enable = mkDefault true;
      geoclue2.enable = mkDefault true;
    };

    # Power Management
    services.tlp = {
      enable = mkDefault true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        START_CHARGE_THRESH_BAT0 = 20;
        STOP_CHARGE_THRESH_BAT0 = 80;
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";
      };
    };

    # Disable conflicting power management
    services.power-profiles-daemon.enable = mkForce false;

    # Thermald for Intel CPUs
    services.thermald.enable = mkDefault true;

    # Auto-mounting
    services.gvfs.enable = mkDefault true;

    # Desktop Environment Variables
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_STYLE_OVERRIDE = "breeze";
    };

    # User Groups for Desktop
    users.users.${config.mySystem.user}.extraGroups = [
      "audio"
      "video"
      "input"
      "lp"
      "scanner"
      "storage"
      "optical"
    ];

    # Ensure desktop groups exist
    users.groups = {
      lp = {};
      scanner = {};
      storage = {};
      optical = {};
    };

    # Console Configuration
    console = {
      keyMap = mkDefault "fi";  # Finnish keyboard layout for console
      font = mkDefault "Lat2-Terminus16";
    };

    # Enable zram for better memory management
    zramSwap = {
      enable = mkDefault true;
      algorithm = "zstd";
      memoryPercent = mkDefault 50;
    };

    # Desktop-specific networking
    networking = {
      networkmanager.enable = mkDefault true;
      firewall = {
        allowedTCPPorts = [
          3389  # RDP
          5900  # VNC (if needed)
        ];
        allowedUDPPorts = [
          5353  # mDNS/Bonjour
        ];
      };
    };

    # Avahi for service discovery
    services.avahi = {
      enable = mkDefault true;
      nssmdns4 = mkDefault true;
      nssmdns6 = mkDefault false;
      openFirewall = mkDefault true;

      publish = {
        enable = mkDefault true;
        addresses = mkDefault true;
        domain = mkDefault true;
        hinfo = mkDefault true;
        userServices = mkDefault true;
        workstation = mkDefault true;
      };
    };


  };
}
