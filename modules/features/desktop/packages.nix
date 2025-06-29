# Desktop Packages Module
# Centralized package management for desktop environments
# Single source of truth for desktop application packages

{ config, lib, pkgs, ... }:

with lib;

let
  desktopCfg = config.mySystem.features.desktop;
  desktopEnvironment = desktopCfg.environment;
  isLowSpec = desktopCfg.lowSpec or false;
in
{
  config = mkIf desktopCfg.enable {
    
    # Common desktop packages (using shared collections)
    environment.systemPackages =
      let
        packages = import ../../packages/common.nix { inherit pkgs; };
      in
      packages.desktopApplications ++
      packages.mediaApplications ++
      packages.desktopUtilities ++
      packages.archiveTools ++
      packages.desktopNetwork ++
      packages.multimediaCodecs ++
      packages.imageViewers ++
      packages.terminalEmulators ++
      optionals (!isLowSpec) [
      # Additional packages for full-featured systems
      inkscape                           # Vector graphics
      discord                            # Communication
      baobab                             # Disk usage analyzer
      kitty                              # Additional terminal
      
    ] ++ optionals (desktopEnvironment == "plasma") [
      # KDE-specific packages
      kdePackages.kate
      kdePackages.konsole
      kdePackages.dolphin
      kdePackages.ark
      kdePackages.okular
      kdePackages.gwenview
      kdePackages.spectacle
      kdePackages.kalk
      kdePackages.kcalc
      kdePackages.kcharselect
      kdePackages.kcolorchooser
      kdePackages.kruler
      kdePackages.filelight
      kdePackages.systemsettings
      kdePackages.plasma-systemmonitor
      kdePackages.ksystemlog
      kdePackages.partitionmanager
      kdePackages.elisa
      kdePackages.dragon
      kdePackages.kdeconnect-kde
      
      # KDE office integration
      libreoffice-qt6-fresh              # Qt6 version for better KDE integration
      
    ] ++ optionals (desktopEnvironment == "xfce") [
      # XFCE-specific packages
      xfce.thunar
      xfce.thunar-volman
      xfce.thunar-archive-plugin
      xfce.xfce4-terminal
      xfce.xfce4-panel
      xfce.xfce4-session
      xfce.xfce4-settings
      xfce.xfce4-appfinder
      xfce.xfce4-screenshooter
      xfce.xfce4-taskmanager
      xfce.xfce4-power-manager
      xfce.xfce4-notifyd
      xfce.xfce4-pulseaudio-plugin
      xfce.xfce4-weather-plugin
      xfce.xfce4-clipman-plugin
      xfce.xfce4-systemload-plugin
      
      # XFCE-specific applications
      mousepad                           # Text editor
      ristretto                          # Image viewer
      xarchiver                          # Archive manager
      
    ] ++ optionals (config.mySystem.features.development.enable && elem "vscode" config.mySystem.features.development.editors) [
      # Development editors (handled by development feature)
      # VS Code is configured in development/vscode.nix
      
    ];

    # Desktop-specific program configurations
    programs = {
      # File manager configurations
      thunar = mkIf (desktopEnvironment == "xfce") {
        enable = true;
        plugins = with pkgs.xfce; [
          thunar-archive-plugin
          thunar-volman
        ];
      };
      
      # KDE Connect
      kdeconnect.enable = mkIf (desktopEnvironment == "plasma") true;
    };

    # Package-specific services
    services = {
      # Flatpak for additional software
      flatpak.enable = mkDefault (!isLowSpec);
      
      # Tumbler for thumbnails
      tumbler.enable = mkDefault true;
      
      # Package management
      packagekit.enable = mkIf (desktopEnvironment == "plasma") (mkDefault true);
    };

    # Application-specific configurations
    environment.etc = {
      # Firefox policies (optional)
      "firefox/policies/policies.json".text = builtins.toJSON {
        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
          DisablePocket = true;
          DisableFirefoxAccounts = false;
          DisableFormHistory = false;
          DisplayBookmarksToolbar = "never";
          DisplayMenuBar = "default-off";
          SearchBar = "unified";
        };
      };
    };

    # Application defaults
    xdg.mime.defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      
      "application/pdf" = if desktopEnvironment == "plasma" 
        then "org.kde.okular.desktop"
        else "evince.desktop";
        
      "image/jpeg" = if desktopEnvironment == "plasma"
        then "org.kde.gwenview.desktop"
        else "ristretto.desktop";
        
      "image/png" = if desktopEnvironment == "plasma"
        then "org.kde.gwenview.desktop"
        else "ristretto.desktop";
        
      "video/mp4" = "vlc.desktop";
      "video/x-matroska" = "vlc.desktop";
      "audio/mpeg" = "vlc.desktop";
      "audio/flac" = "vlc.desktop";
      
      "application/zip" = if desktopEnvironment == "plasma"
        then "org.kde.ark.desktop"
        else "xarchiver.desktop";
        
      "text/plain" = if desktopEnvironment == "plasma"
        then "org.kde.kate.desktop"
        else "mousepad.desktop";
    };

    # Desktop-specific environment variables for applications
    environment.sessionVariables = {
      # Browser configuration
      BROWSER = "firefox";
      
      # Default applications
      TERMINAL = if desktopEnvironment == "plasma" 
        then "konsole"
        else "xfce4-terminal";
        
      # Application-specific settings
      GIMP2_DIRECTORY = "$HOME/.config/GIMP/2.10";
      
      # LibreOffice configuration
      SAL_USE_VCLPLUGIN = if desktopEnvironment == "plasma" 
        then "kf5" 
        else "gtk3";
    };

    # Assertions for package consistency
    assertions = [
      {
        assertion = !(desktopEnvironment == "plasma" && isLowSpec);
        message = "KDE Plasma is not recommended for low-spec systems. Consider using XFCE instead.";
      }
    ];

    # Warnings for package selection
    warnings = []
      ++ optional (desktopEnvironment == "plasma" && isLowSpec)
         "KDE Plasma may be resource-intensive for low-spec hardware"
      ++ optional (desktopEnvironment == "xfce" && !isLowSpec)
         "XFCE is optimized for low-spec systems. Consider KDE Plasma for full-featured experience";
  };
}
