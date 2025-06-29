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
      
      # Touchpad configuration
      libinput = {
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

    # Wayland Configuration
    programs.wayland = mkIf isWaylandEnabled {
      enable = true;
    };

    # XWayland support (for running X11 apps on Wayland)
    programs.xwayland.enable = mkIf isWaylandEnabled true;

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

    # XFCE X11 optimizations
    environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml".text = mkIf (desktopEnvironment == "xfce") ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfwm4" version="1.0">
        <property name="general" type="empty">
          <property name="activate_action" type="string" value="bring"/>
          <property name="borderless_maximize" type="bool" value="true"/>
          <property name="box_move" type="bool" value="false"/>
          <property name="box_resize" type="bool" value="false"/>
          <property name="button_layout" type="string" value="O|SHMC"/>
          <property name="click_to_focus" type="bool" value="true"/>
          <property name="cycle_apps_only" type="bool" value="false"/>
          <property name="cycle_draw_frame" type="bool" value="true"/>
          <property name="cycle_raise" type="bool" value="false"/>
          <property name="cycle_hidden" type="bool" value="true"/>
          <property name="cycle_minimum" type="bool" value="true"/>
          <property name="cycle_preview" type="bool" value="true"/>
          <property name="cycle_tabwin_mode" type="int" value="0"/>
          <property name="cycle_workspaces" type="bool" value="false"/>
          <property name="double_click_action" type="string" value="maximize"/>
          <property name="double_click_distance" type="int" value="5"/>
          <property name="double_click_time" type="int" value="250"/>
          <property name="easy_click" type="string" value="Alt"/>
          <property name="focus_delay" type="int" value="10"/>
          <property name="focus_hint" type="bool" value="true"/>
          <property name="focus_new" type="bool" value="true"/>
          <property name="frame_opacity" type="int" value="100"/>
          <property name="full_width_title" type="bool" value="true"/>
          <property name="inactive_opacity" type="int" value="100"/>
          <property name="maximized_offset" type="int" value="0"/>
          <property name="mousewheel_rollup" type="bool" value="true"/>
          <property name="move_opacity" type="int" value="100"/>
          <property name="placement_mode" type="string" value="center"/>
          <property name="placement_ratio" type="int" value="20"/>
          <property name="popup_opacity" type="int" value="100"/>
          <property name="prevent_focus_stealing" type="bool" value="false"/>
          <property name="raise_delay" type="int" value="250"/>
          <property name="raise_on_click" type="bool" value="true"/>
          <property name="raise_on_focus" type="bool" value="false"/>
          <property name="raise_with_any_button" type="bool" value="true"/>
          <property name="repeat_urgent_blink" type="bool" value="false"/>
          <property name="resize_opacity" type="int" value="100"/>
          <property name="restore_on_move" type="bool" value="true"/>
          <property name="scroll_workspaces" type="bool" value="true"/>
          <property name="shadow_delta_height" type="int" value="0"/>
          <property name="shadow_delta_width" type="int" value="0"/>
          <property name="shadow_delta_x" type="int" value="0"/>
          <property name="shadow_delta_y" type="int" value="-3"/>
          <property name="shadow_opacity" type="int" value="50"/>
          <property name="show_app_icon" type="bool" value="false"/>
          <property name="show_dock_shadow" type="bool" value="true"/>
          <property name="show_frame_shadow" type="bool" value="true"/>
          <property name="show_popup_shadow" type="bool" value="false"/>
          <property name="snap_resist" type="bool" value="false"/>
          <property name="snap_to_border" type="bool" value="true"/>
          <property name="snap_to_windows" type="bool" value="false"/>
          <property name="snap_width" type="int" value="10"/>
          <property name="theme" type="string" value="Default"/>
          <property name="tile_on_move" type="bool" value="true"/>
          <property name="title_alignment" type="string" value="center"/>
          <property name="title_font" type="string" value="Sans Bold 9"/>
          <property name="title_horizontal_offset" type="int" value="0"/>
          <property name="title_shadow_active" type="string" value="false"/>
          <property name="title_shadow_inactive" type="string" value="false"/>
          <property name="title_vertical_offset_active" type="int" value="0"/>
          <property name="title_vertical_offset_inactive" type="int" value="0"/>
          <property name="toggle_workspaces" type="bool" value="false"/>
          <property name="unredirect_overlays" type="bool" value="true"/>
          <property name="urgent_blink" type="bool" value="false"/>
          <property name="use_compositing" type="bool" value="${if desktopCfg.lowSpec then "false" else "true"}"/>
          <property name="workspace_count" type="int" value="4"/>
          <property name="workspace_names" type="array">
            <value type="string" value="Workspace 1"/>
            <value type="string" value="Workspace 2"/>
            <value type="string" value="Workspace 3"/>
            <value type="string" value="Workspace 4"/>
          </property>
          <property name="wrap_cycle" type="bool" value="true"/>
          <property name="wrap_layout" type="bool" value="true"/>
          <property name="wrap_resistance" type="int" value="10"/>
          <property name="wrap_windows" type="bool" value="true"/>
          <property name="wrap_workspaces" type="bool" value="false"/>
          <property name="zoom_desktop" type="bool" value="true"/>
        </property>
      </channel>
    '';

    # Assertions to ensure valid configuration
    assertions = [
      {
        assertion = isWaylandEnabled || isX11Enabled;
        message = "At least one display server (Wayland or X11) must be enabled";
      }
      {
        assertion = !(desktopEnvironment == "xfce" && isWaylandEnabled && !isX11Enabled);
        message = "XFCE requires X11 support (Wayland support is experimental)";
      }
    ];

    # Warnings for suboptimal configurations
    warnings = []
      ++ optional (desktopEnvironment == "xfce" && isWaylandEnabled)
         "XFCE with Wayland is experimental and may have issues"
      ++ optional (desktopEnvironment == "plasma" && !isWaylandEnabled && isX11Enabled)
         "KDE Plasma works best with Wayland enabled"
      ++ optional (desktopCfg.lowSpec && isWaylandEnabled)
         "Wayland may use more resources than X11 on low-spec hardware";
  };
}
