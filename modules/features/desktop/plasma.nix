# KDE Plasma 6 Desktop Environment Module
# Full-featured desktop environment for modern hardware

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./common.nix
  ];
  config = mkIf (config.mySystem.features.desktop.enable && 
                 config.mySystem.features.desktop.environment == "plasma") {
    
    # KDE Plasma 6 Desktop Environment
    services.desktopManager.plasma6.enable = true;
    
    # Display Manager - SDDM with Wayland support
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = config.mySystem.features.desktop.enableWayland;
      theme = mkDefault "breeze";
      settings = {
        Theme = {
          Current = "breeze";
          CursorTheme = "breeze_cursors";
          CursorSize = 24;
        };
        General = {
          HaltCommand = "/run/current-system/systemd/bin/systemctl poweroff";
          RebootCommand = "/run/current-system/systemd/bin/systemctl reboot";
        };
        Wayland = mkIf config.mySystem.features.desktop.enableWayland {
          SessionDir = "/run/current-system/sw/share/wayland-sessions";
        };
        X11 = mkIf config.mySystem.features.desktop.enableX11 {
          SessionDir = "/run/current-system/sw/share/xsessions";
        };
      };
    };

    # KDE-specific services
    services = {
      # KDE Connect for mobile integration
      kdeconnect.enable = mkDefault true;
      
      # Discover backend for software management
      packagekit.enable = mkDefault true;
      
      # Flatpak integration
      flatpak.enable = mkDefault true;
    };

    # KDE Plasma specific packages (common packages are in packages.nix)
    environment.systemPackages = with pkgs; [
      # KDE-specific development tools (if development is enabled)
    ] ++ optionals config.mySystem.features.development.enable [
      kdePackages.kdevelop               # IDE
      kdePackages.umbrello               # UML modeler
      kdePackages.krfb                   # Desktop sharing
      kdePackages.krdc                   # Remote desktop client
      kdePackages.kamoso                 # Camera application
      kdePackages.kmail                  # Email client (optional)
      kdePackages.kontact                # PIM suite (optional)
    ];

    # KDE-specific environment variables
    environment.sessionVariables = {
      # Qt/KDE theming
      QT_QPA_PLATFORM = mkIf config.mySystem.features.desktop.enableWayland "wayland;xcb";
      QT_STYLE_OVERRIDE = "breeze";
      QT_QPA_PLATFORMTHEME = "kde";

      # KDE-specific
      KDE_SESSION_VERSION = "6";
      KDE_FULL_SESSION = "true";
    } // optionalAttrs config.mySystem.features.desktop.enableWayland {
      # Wayland-specific environment variables
      NIXOS_OZONE_WL = "1";              # Chromium/Electron Wayland
      MOZ_ENABLE_WAYLAND = "1";          # Firefox Wayland
      XDG_SESSION_TYPE = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    } // optionalAttrs config.mySystem.features.desktop.enableX11 {
      # X11-specific environment variables
      QT_X11_NO_MITSHM = "1";           # Fix for some X11 issues
      _JAVA_AWT_WM_NONREPARENTING = "1"; # Fix Java applications
    };

    # KDE Plasma configuration
    programs.kdeconnect.enable = mkDefault true;
    
    # XDG Portal configuration is handled by common.nix

    # Additional KDE-specific fonts (base fonts are in common.nix)
    fonts.packages = with pkgs; [
      oxygen-fonts
    ];

    # Hardware configuration is handled by common.nix

    # User groups are handled by common.nix

    # Performance optimizations for KDE Plasma
    boot.kernel.sysctl = {
      # Improve desktop responsiveness
      "vm.swappiness" = mkDefault 10;
      "vm.vfs_cache_pressure" = mkDefault 50;
    };

    # KDE-specific services configuration
    services.xserver = {
      enable = true;
      
      # Touchpad configuration for KDE
      libinput = {
        enable = true;
        touchpad = {
          tapping = true;
          naturalScrolling = true;
          middleEmulation = true;
          disableWhileTyping = true;
        };
      };
    };

    # Networking configuration is handled by common.nix

    # KDE theming and appearance
    qt = {
      enable = true;
      platformTheme = "kde";
      style = "breeze";
    };

    # Low-spec optimizations (if enabled)
    environment.etc."kderc".text = mkIf config.mySystem.features.desktop.lowSpec ''
      [KDE Performance]
      AnimationDurationFactor=0.5
      GraphicsSystem=raster
      
      [Compositing]
      Enabled=true
      Backend=OpenGL
      GLCore=true
      
      [Effects]
      kwin4_effect_fadeEnabled=false
      kwin4_effect_slidingpopupsEnabled=false
      kwin4_effect_translucencyEnabled=false
    '';
  };
}
