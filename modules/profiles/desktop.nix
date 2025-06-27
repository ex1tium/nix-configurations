# Desktop Profile - Lightweight desktop for basic usage and thin clients
# Target: Low-spec machines, basic productivity, remote access

{ config, lib, pkgs, globalConfig, profileConfig, finalFeatures, ... }:

with lib;

{
  imports = [
    ../nixos/core.nix
    ../nixos/users.nix
    ../nixos/networking.nix
    ../nixos/security.nix
  ] ++ optionals finalFeatures.desktop.enable [
    ../nixos/desktop.nix
  ];

  # Desktop profile configuration
  mySystem = {
    enable = true;
    
    # Basic system settings from global config
    hostname = mkDefault "desktop";
    user = globalConfig.defaultUser;
    timezone = globalConfig.defaultTimezone;
    locale = globalConfig.defaultLocale;
    stateVersion = globalConfig.defaultStateVersion;

    # Desktop profile features
    features = finalFeatures;

    # Desktop-specific settings
    desktop = mkIf finalFeatures.desktop.enable {
      enable = true;
      environment = mkDefault "plasma"; # KDE Plasma 6 primary, XFCE fallback
      displayManager = "sddm";
      enableWayland = true;
      enableX11 = true;
      enableRemoteDesktop = mkDefault true; # For remote access use cases
    };

    # Minimal development tools
    development = {
      enable = false; # Desktop profile doesn't include development by default
    };

    # Basic virtualization (disabled by default for lightweight systems)
    virtualization = {
      enable = false;
    };

    # Enhanced security for desktop usage
    security = {
      enable = true;
      enableHardening = true;
      enableSecretsManagement = true;
      enableAppArmor = true;
    };

    # Network configuration optimized for desktop
    networking = {
      enable = true;
      enableWifi = true;
      enableBluetooth = true;
      enableFirewall = true;
      enableAvahi = true; # For network discovery
    };
  };

  # Desktop profile packages
  environment.systemPackages = with pkgs; [
    # Browsers - modern and privacy-focused
    brave
    firefox
    
    # Remote access tools
    remmina
    freerdp
    
    # Hardware management
    solaar # Logitech device management
    
    # Media
    vlc
    
    # Graphics
    gimp
    
    # File transfer
    filezilla
    
    # Terminal and communication
    tmux
    irssi
    ghostty
    
    # Windows compatibility
    bottles
    
    # Utilities
    balenaetcher
    
    # Essential desktop tools
    libreoffice-qt6-fresh
    thunderbird
    
    # File management
    dolphin
    ark
    
    # System utilities
    gparted
    baobab
    
    # Modern CLI tools (shared base)
    bat
    eza
    fd
    ripgrep
    fzf
    zoxide
    htop
    btop
    tree
    wget
    curl
    git
    vim
    
    # Font for consistent experience
    (nerdfonts.override { fonts = [ "FiraCode" ]; })
  ];

  # Desktop-specific services
  services = {
    # Enable printing for office use
    printing.enable = true;
    
    # Enable scanning
    sane.enable = true;
    
    # Enable CUPS for printer discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
    };
    
    # Remote desktop for support
    xrdp = mkIf config.mySystem.desktop.enableRemoteDesktop {
      enable = true;
      defaultWindowManager = if config.mySystem.desktop.environment == "plasma" 
                            then "startplasma-x11" 
                            else "startxfce4";
    };
  };

  # Hardware support for desktop peripherals
  hardware = {
    # Enable all firmware for hardware compatibility
    enableRedistributableFirmware = true;
    
    # Bluetooth for peripherals
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    
    # Audio support
    pulseaudio.enable = false; # Use PipeWire instead
  };

  # Modern audio with PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Desktop user configuration
  users.users.${config.mySystem.user} = {
    packages = with pkgs; [
      # Additional user-specific desktop applications
      discord
      signal-desktop
      
      # Productivity
      obsidian
      
      # Media creation (basic)
      audacity
      
      # Development (minimal for basic scripting)
      vscode
    ];
  };

  # Fonts for desktop experience
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
    ];
    
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "FiraCode Nerd Font Mono" ];
      };
    };
  };

  # XDG portal for modern desktop integration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ] ++ optionals (config.mySystem.desktop.environment == "plasma") [
      xdg-desktop-portal-kde
    ];
  };

  # Power management for laptops/mobile devices
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Automatic updates for security (desktop systems)
  system.autoUpgrade = {
    enable = mkDefault false; # Can be enabled per machine
    dates = "04:00";
    allowReboot = false;
  };

  # Desktop-specific kernel
  boot.kernelPackages = mkDefault pkgs.linuxPackages_latest;

  # Desktop-optimized kernel parameters
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
  ];

  # Enable zram for better memory management on lower-spec systems
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
}
