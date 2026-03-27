# Display Server Configuration Module
# Handles X11 and Wayland configuration for desktop environments

{ config, lib, pkgs, ... }:

with lib;

let
  desktopCfg = config.mySystem.features.desktop;
  isWaylandEnabled = desktopCfg.enableWayland;
  isX11Enabled = desktopCfg.enableX11;
  desktopEnvironment = desktopCfg.environment;
  gpuType = config.mySystem.hardware.gpu.vendor;

  # GPU-vendor specific X11 input/video modules (added to services.xserver.modules)
  # Use canonical nixpkgs attribute paths (xorg.*) to avoid broken hyphenated lookups.
  # Note: intel uses the modesetting driver (set in videoDrivers); xf86-video-intel
  # is legacy and conflicts with modesetting on 4th-gen+ hardware, so it is omitted.
  x11VideoDrivers =
    [ pkgs.xf86-input-libinput ] ++  # Always include libinput input driver
    (optionals (gpuType == "amd") [ pkgs.xf86-video-ati ]) ++
    (optionals (gpuType == "nvidia") [ pkgs.xf86-video-nouveau ]);
in
{
  config = mkIf desktopCfg.enable {
    
    # X11 / XKB Configuration
    # mkMerge allows unconditional xkb settings alongside conditional X11 settings.
    # xkb is set unconditionally so SDDM/KWin picks it up via systemd-localed
    # regardless of whether X11 is enabled.
    services.xserver = mkMerge [
      {
        xkb = {
          layout = mkDefault "fi";
          variant = mkDefault "";
          # xkb options (e.g. AltGr, group switching) are set exclusively in locale-fi.nix
          # to avoid duplication — NixOS merges comma-list strings from multiple modules.
        };
      }
      (mkIf isX11Enabled {
        enable = true;

        # Touchpad configuration (moved to services.libinput in NixOS 25.05)
        # libinput = { ... };

        # X11 performance optimizations
        deviceSection = ''
          Option "TearFree" "true"
          Option "DRI" "3"
          Option "AccelMethod" "glamor"
        '';

        # X11 modules - GPU-vendor specific drivers
        modules = x11VideoDrivers;
      })
    ];

    # XWayland support (for running X11 apps on Wayland)
    programs.xwayland.enable = mkIf isWaylandEnabled true;

    # Libinput Configuration (new structure in NixOS 25.05)
    services.libinput = {
      enable = mkDefault true;
      touchpad = {
        tapping = mkDefault true;
        naturalScrolling = mkDefault false;     # traditional scroll direction
        middleEmulation = mkDefault true;
        disableWhileTyping = mkDefault true;
        scrollMethod = mkDefault "twofinger";
        clickMethod = mkDefault "buttonareas";  # bottom-right = right-click, bottom-center = middle
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
      xrandr                             # Display configuration
      xdpyinfo                           # Display information
      xwininfo                           # Window information
      xprop                              # Window properties
      xev                                # Event viewer
      arandr                             # GUI display configuration
      autorandr                          # Automatic display configuration
    ] ++ optionals isWaylandEnabled [
      wl-clipboard                       # Wayland clipboard utilities
      wlr-randr                          # Wayland display configuration
      wayland-utils                      # Wayland utilities
      xwayland                           # X11 compatibility layer
    ];

    # Display/session backend variables are set by the display manager and session.

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
    environment.etc = mkIf (desktopEnvironment == "plasma" && isWaylandEnabled) {
      "xdg/kwinrc".text = ''
        [Wayland]
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
    };

    # XFCE X11 optimizations are now handled in the XFCE module

    # Validation is handled by the comprehensive validation module
  };
}
