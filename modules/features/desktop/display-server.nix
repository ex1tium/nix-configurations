# Display Server Configuration Module
# Handles X11 and Wayland configuration for desktop environments

{ config, lib, pkgs, ... }:

with lib;

let
  desktopCfg = config.mySystem.features.desktop;
  isWaylandEnabled = desktopCfg.enableWayland;
  isX11Enabled = desktopCfg.enableX11;
  desktopEnvironment = desktopCfg.environment;
in
{
  config = mkIf desktopCfg.enable {
    
    # X11 Configuration
    services.xserver = mkIf isX11Enabled {
      enable = true;
      
      # Keyboard configuration
      xkb = {
        layout = mkDefault "fi";
        variant = mkDefault "";
        options = mkDefault "grp:alt_shift_toggle,compose:ralt";
      };
      
      # Touchpad configuration (moved to services.libinput in NixOS 25.05)
      # libinput = {
      #   enable = mkDefault true;
      #   touchpad = {
      #     tapping = mkDefault true;
      #     naturalScrolling = mkDefault true;
      #     middleEmulation = mkDefault true;
      #     disableWhileTyping = mkDefault true;
      #     scrollMethod = mkDefault "twofinger";
      #     clickMethod = mkDefault "clickfinger";
      #   };
      #   mouse = {
      #     accelProfile = mkDefault "adaptive";
      #     accelSpeed = mkDefault "0";
      #   };
      # };
      
      # X11 performance optimizations
      deviceSection = ''
        Option "TearFree" "true"
        Option "DRI" "3"
        Option "AccelMethod" "glamor"
      '';
      
      # X11 modules
      modules = with pkgs.xorg; [
        xf86inputlibinput
        xf86videoati
        xf86videointel
        xf86videonouveau
      ];
    };

    # XWayland support (for running X11 apps on Wayland)
    programs.xwayland.enable = mkIf isWaylandEnabled true;

    # Libinput Configuration (new structure in NixOS 25.05)
    services.libinput = {
      enable = mkDefault true;
      touchpad = {
        tapping = mkDefault true;
        naturalScrolling = mkDefault true;
        middleEmulation = mkDefault true;
        disableWhileTyping = mkDefault true;
        scrollMethod = mkDefault "twofinger";
        clickMethod = mkDefault "clickfinger";
      };
      mouse = {
        accelProfile = mkDefault "adaptive";
        accelSpeed = mkDefault "0";
      };
    };

    # Common display server packages
    environment.systemPackages = with pkgs; [
      # X11 utilities
    ] ++ optionals isX11Enabled [
      xorg.xrandr                        # Display configuration
      xorg.xdpyinfo                      # Display information
      xorg.xwininfo                      # Window information
      xorg.xprop                         # Window properties
      xorg.xev                           # Event viewer
      arandr                             # GUI display configuration
      autorandr                          # Automatic display configuration
    ] ++ optionals isWaylandEnabled [
      wl-clipboard                       # Wayland clipboard utilities
      wlr-randr                          # Wayland display configuration
      wayland-utils                      # Wayland utilities
      xwayland                           # X11 compatibility layer
    ];

    # Environment variables for display servers
    environment.sessionVariables = {
      # Common variables
      XDG_SESSION_TYPE = mkIf isWaylandEnabled "wayland";
      
      # X11-specific variables
    } // optionalAttrs isX11Enabled {
      DISPLAY = ":0";
      XAUTHORITY = "$HOME/.Xauthority";
    } // optionalAttrs isWaylandEnabled {
      # Wayland-specific variables
      WAYLAND_DISPLAY = "wayland-0";
      QT_QPA_PLATFORM = "wayland;xcb";
      GDK_BACKEND = "wayland,x11";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      
      # Application-specific Wayland support
      NIXOS_OZONE_WL = "1";              # Chromium/Electron
      MOZ_ENABLE_WAYLAND = "1";          # Firefox
      _JAVA_AWT_WM_NONREPARENTING = "1"; # Java applications
    };

    # Security and permissions
    security = {
      # Polkit for desktop authentication
      polkit.enable = mkDefault true;
      
      # PAM configuration for display managers
      pam.services = mkIf isX11Enabled {
        lightdm.enableGnomeKeyring = mkDefault true;
        sddm.enableGnomeKeyring = mkDefault true;
      };
    };

    # Hardware support for display servers
    hardware = {
      # Graphics support is handled by gpu.nix module
      
      # Input device support
      uinput.enable = mkDefault true;
    };

    # Fonts for display servers
    fonts = {
      enableDefaultPackages = true;
      fontconfig = {
        enable = true;
        antialias = true;
        hinting = {
          enable = true;
          style = "slight";
        };
        subpixel = {
          rgba = "rgb";
          lcdfilter = "default";
        };
        defaultFonts = {
          serif = [ "Noto Serif" "Liberation Serif" ];
          sansSerif = [ "Noto Sans" "Liberation Sans" ];
          monospace = [ "FiraCode Nerd Font Mono" "JetBrains Mono" ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };

    # Desktop environment specific display server configuration
    
    # KDE Plasma Wayland optimizations
    environment.etc."xdg/kwinrc".text = mkIf (desktopEnvironment == "plasma" && isWaylandEnabled) ''
      [Wayland]
      InputMethod=
      XwaylandScale=1
      
      [Compositing]
      Backend=OpenGL
      GLCore=true
      HideCursor=true
      OpenGLIsUnsafe=false
      WindowsBlockCompositing=true
      
      [Effect-PresentWindows]
      BorderActivate=9
      BorderActivateAll=7
      BorderActivateClass=9
      
      [MouseBindings]
      CommandActiveTitlebar1=Raise
      CommandActiveTitlebar2=Nothing
      CommandActiveTitlebar3=Operations menu
    '';

    # XFCE X11 optimizations are now handled in the XFCE module

    # Validation is handled by the comprehensive validation module
  };
}
