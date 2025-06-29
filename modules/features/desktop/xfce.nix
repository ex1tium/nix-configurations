# XFCE Desktop Environment Module
# Lightweight desktop environment for low-spec machines

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./common.nix
  ];
  config = mkIf (config.mySystem.features.desktop.enable && 
                 config.mySystem.features.desktop.environment == "xfce") {
    
    # XFCE Desktop Environment
    services.xserver = {
      enable = true;
      desktopManager.xfce.enable = true;

      # Display manager - LightDM for XFCE (lighter than SDDM)
      displayManager.lightdm = {
        enable = true;
        greeters.gtk = {
          enable = true;
          theme = {
            name = "Adwaita-dark";
            package = pkgs.gnome.gnome-themes-extra;
          };
          iconTheme = {
            name = "Adwaita";
            package = pkgs.gnome.adwaita-icon-theme;
          };
          cursorTheme = {
            name = "Adwaita";
            package = pkgs.gnome.adwaita-icon-theme;
            size = 16;
          };
        };
        extraSeatDefaults = ''
          # Force X11 for XFCE (Wayland support is experimental)
          user-session=xfce
        '';
      };
    };

    # XFCE-specific services
    services = {
      # Thunar file manager support
      gvfs.enable = mkDefault true;
      tumbler.enable = mkDefault true;
      
      # Power management for laptops
      upower.enable = mkDefault true;
      
      # Printing support
      printing.enable = mkDefault true;
      
      # Audio support is handled by common.nix
    };

    # XFCE specific packages (common packages are in packages.nix)
    environment.systemPackages = with pkgs; [
      # Additional XFCE-specific utilities
      pavucontrol                        # Audio control
      htop                               # System monitor
      file-roller                        # Archive manager alternative

      # Development tools (minimal set if development enabled)
    ] ++ optionals config.mySystem.features.development.enable [
      # Lightweight development tools
      geany                              # Lightweight IDE
      git-cola                           # Git GUI
    ];

    # XFCE-specific environment variables
    environment.sessionVariables = {
      # GTK theming
      GTK_THEME = "Adwaita:dark";

      # XFCE-specific
      XDG_CURRENT_DESKTOP = "XFCE";
      XDG_SESSION_DESKTOP = "xfce";
      XDG_SESSION_TYPE = "x11";          # Force X11 for XFCE

      # Disable heavy animations for performance
      GTK_CSD = "0";                     # Disable client-side decorations

      # X11-specific optimizations
      _JAVA_AWT_WM_NONREPARENTING = "1"; # Fix Java applications
      QT_X11_NO_MITSHM = "1";           # Fix Qt applications
    };

    # XDG Portal configuration is handled by common.nix

    # XFCE-specific fonts (base fonts are in common.nix)
    fonts.packages = with pkgs; [
      # Lightweight font selection for XFCE
      source-sans-pro
      source-serif-pro
    ];

    # Hardware configuration is handled by common.nix
    # Override Bluetooth for low-spec systems
    hardware.bluetooth.enable = mkForce false;

    # Performance optimizations for XFCE
    boot.kernel.sysctl = {
      # Optimize for low-spec hardware
      "vm.swappiness" = mkDefault 60;      # Higher swappiness for low RAM
      "vm.vfs_cache_pressure" = mkDefault 100;
      "vm.dirty_ratio" = mkDefault 15;
      "vm.dirty_background_ratio" = mkDefault 5;
    };

    # XFCE-specific services configuration
    # Libinput configuration is now handled by display-server.nix with the new structure
    # Override specific settings for XFCE if needed
    services.libinput.touchpad.naturalScrolling = mkForce false;  # Traditional scrolling for older users

    # Networking configuration is handled by common.nix
    # Override power saving for low-spec systems
    networking.networkmanager.wifi.powersave = mkForce true;

    # GTK theming for XFCE
    programs.dconf.enable = true;
    
    # User groups are handled by common.nix

    # Disable heavy services for performance
    services = {
      # Disable indexing for performance
      locate.enable = mkForce false;
      
      # Disable unnecessary services
      packagekit.enable = mkForce false;
      flatpak.enable = mkDefault false;    # Disabled by default for low-spec
      
      # Minimal power management
      tlp = {
        enable = mkDefault true;
        settings = {
          # Aggressive power saving
          CPU_SCALING_GOVERNOR_ON_AC = "ondemand";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          WIFI_PWR_ON_AC = "on";
          WIFI_PWR_ON_BAT = "on";
        };
      };
    };

    # XFCE compositor settings for low-spec hardware
    environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfwm4" version="1.0">
        <property name="general" type="empty">
          <property name="use_compositing" type="bool" value="false"/>
          <property name="frame_opacity" type="int" value="100"/>
          <property name="inactive_opacity" type="int" value="100"/>
          <property name="popup_opacity" type="int" value="100"/>
          <property name="show_frame_shadow" type="bool" value="false"/>
          <property name="show_popup_shadow" type="bool" value="false"/>
        </property>
      </channel>
    '';

    # Disable heavy desktop effects (temporarily disabled)
    # environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml".text = ''
    #   <?xml version="1.0" encoding="UTF-8"?>
    #   <channel name="xfce4-desktop" version="1.0">
    #     <property name="backdrop" type="empty">
    #       <property name="screen0" type="empty">
    #         <property name="monitor0" type="empty">
    #           <property name="workspace0" type="empty">
    #             <property name="color-style" type="int" value="0"/>
    #             <property name="image-style" type="int" value="0"/>
    #           </property>
    #         </property>
    #       </property>
    #     </property>
    #   </channel>
    # '';

    # Memory optimization
    zramSwap = {
      enable = mkDefault true;
      algorithm = "lz4";                  # Faster compression for low-spec
      memoryPercent = mkDefault 25;       # Conservative for low RAM
    };
  };
}
