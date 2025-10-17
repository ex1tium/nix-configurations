# Centralized Default Values
# Single source of truth for all default configurations across the system
# This module provides consistent defaults for system, features, and hardware settings

{ lib }:

with lib;

{
  # System-wide default configuration
  # These values are used across all profiles and can be overridden per machine
  system = {
    # NixOS version and state management
    stateVersion = "25.05";           # NixOS 25.05 (unstable) as per user preference
    nixosVersion = "25.05";           # Consistent version management
    
    # Localization defaults (Finnish setup with English language)
    timezone = "Europe/Helsinki";     # Finnish timezone
    locale = "en_US.UTF-8";          # English language with UTF-8
    keyboardLayout = "fi";           # Finnish keyboard layout
    
    # User management defaults
    defaultUser = "ex1tium";         # Primary user account
    defaultShell = "zsh";            # ZSH as default shell
    
    # Network defaults
    enableIPv6 = false;              # IPv6 disabled by default
    enableNetworkManager = true;     # NetworkManager for desktop systems
    
    # Security defaults
    enableFirewall = true;           # Firewall enabled by default
    allowPing = true;                # Allow ping responses
    sshPasswordAuth = true;          # SSH password auth (can be disabled per machine)
    
    # Boot and kernel defaults
    bootLoader = "systemd-boot";     # Modern UEFI boot loader
    kernelParams = [                 # Verbose kernel parameters for debugging boot issues
      # "quiet" # Intentionally disabled for debugging
      "loglevel=7"
      "systemd.log_level=debug"
      "systemd.show_status=true"
      "rd.udev.log_level=7"
    ];
    
    # Package management defaults
    allowUnfree = true;              # Allow unfree packages
    autoOptimiseStore = true;        # Automatic Nix store optimization
    autoGarbageCollection = true;    # Automatic garbage collection
    gcDates = "weekly";              # Weekly garbage collection
    gcOptions = "--delete-older-than 7d";  # Keep last 7 days
    
    # Documentation defaults
    enableDocumentation = true;      # Enable system documentation
    enableManPages = true;           # Enable manual pages
    enableNixOSManual = true;        # Enable NixOS manual
    enableInfoPages = false;         # Disable info pages (less common)
    enableDocPages = false;          # Disable doc pages (space saving)
  };

  # Feature-specific default configurations
  # Default settings for each feature when enabled
  features = {
    # Desktop environment defaults
    desktop = {
      enable = false;                # Disabled by default (enabled in desktop profiles)
      environment = "plasma";        # KDE Plasma 6 as primary desktop
      displayManager = "sddm";       # SDDM display manager for Plasma
      enableWayland = true;          # Wayland support enabled
      enableX11 = true;              # X11 fallback support
      enableRemoteDesktop = false;   # Remote desktop disabled by default
      lowSpec = false;               # Not optimized for low-spec by default
      
      # Desktop application defaults
      defaultBrowser = "firefox";    # Firefox as default browser
      defaultTerminal = "konsole";   # Konsole for Plasma, overridden for XFCE
      defaultEditor = "nano";        # Nano as user-friendly editor

      # Desktop environment-specific application mappings
      terminalByEnvironment = {
        plasma = "konsole";          # KDE Plasma uses Konsole
        xfce = "xfce4-terminal";     # XFCE uses its native terminal
      };

      # LibreOffice plugin selection by desktop environment
      libreOfficePluginByEnvironment = {
        plasma = "kf5";              # KDE Plasma uses KF5 plugin
        xfce = "gtk3";               # XFCE uses GTK3 plugin
      };
      
      # Desktop service defaults
      enableFlatpak = true;          # Flatpak enabled for additional software
      enableThumbnails = true;       # Thumbnail generation enabled
      enablePrinting = true;         # Printing support enabled
      enableScanning = true;         # Scanner support enabled
      enableBluetooth = true;        # Bluetooth enabled for desktop
      
      # Audio defaults
      audioSystem = "pipewire";      # PipeWire as modern audio system
      enableJack = true;             # JACK support for audio production
      enablePulseCompat = true;      # PulseAudio compatibility
    };

    # Development environment defaults
    development = {
      enable = false;                # Disabled by default (enabled in dev profiles)
      languages = [ "nix" ];         # Nix language support always included
      editors = [ "vim" ];           # Vim as minimal editor
      enableContainers = false;      # Container support disabled by default
      enableVirtualization = false;  # Virtualization disabled by default
      enableDatabases = false;       # Database tools disabled (use containers)
      
      # Development tool defaults
      defaultEditor = "nano";        # Nano for user-friendly editing
      defaultBrowser = "firefox";    # Firefox for web development
      enableGitLFS = true;           # Git LFS support enabled
      enableGitCrypt = true;         # Git encryption support
      
      # Language-specific defaults
      nodeVersion = "latest";        # Latest Node.js version
      goVersion = "latest";          # Latest Go version
      pythonVersion = "3";           # Python 3.x
      rustChannel = "stable";        # Stable Rust channel
      
      # Development environment defaults
      enableDirenv = true;           # Direnv for environment management
      enableShellIntegration = true; # Enhanced shell integration
      enableDocumentation = true;    # Development documentation
    };

    # Virtualization defaults
    virtualization = {
      enable = false;                # Disabled by default
      enableDocker = false;          # Docker disabled by default
      enablePodman = false;          # Podman disabled by default
      enableLibvirt = false;         # libvirt/KVM disabled by default
      enableVirtualbox = false;      # VirtualBox disabled by default
      enableWaydroid = false;        # Waydroid disabled by default
      
      # Container defaults
      dockerAutoPrune = true;        # Automatic Docker cleanup
      podmanAutoPrune = true;        # Automatic Podman cleanup
      pruneSchedule = "weekly";      # Weekly cleanup schedule
      
      # Virtualization performance defaults
      enableKVM = true;              # KVM acceleration when available
      enableNestedVirtualization = false;  # Nested virt disabled by default
      enableGPUPassthrough = false;  # GPU passthrough disabled by default
    };

    # Server-specific defaults
    server = {
      enable = false;                # Disabled by default
      enableMonitoring = false;      # Monitoring disabled by default
      enableBackup = false;          # Backup disabled by default
      enableWebServer = false;       # Web server disabled by default
      
      # Server security defaults
      enableFail2ban = true;         # Intrusion prevention enabled
      fail2banMaxRetry = 3;          # Maximum login attempts
      fail2banBanTime = "1h";        # Ban duration
      
      # Server networking defaults
      enableWiFi = false;            # WiFi disabled on servers
      enableBluetooth = false;       # Bluetooth disabled on servers
      enableNetworkManager = false;  # NetworkManager disabled on servers
      
      # Server resource defaults
      enableSwap = false;            # Swap disabled on servers
      enableZramSwap = false;        # zram swap disabled by default
      zramPercentage = 10;           # Conservative zram usage
      
      # Server power management
      cpuGovernor = "performance";   # Performance CPU governor
      enableTLP = false;             # TLP disabled on servers
      enableThermald = false;        # Thermald disabled on servers
    };
  };

  # Hardware-specific default configurations
  # Default settings for different hardware configurations
  hardware = {
    # Kernel defaults
    kernel = "stable";               # Stable kernel by default
    kernelPackages = "linuxPackages"; # Default kernel package set
    
    # CPU defaults
    enableMicrocode = true;          # Microcode updates enabled
    cpuGovernor = "ondemand";        # Balanced CPU governor
    
    # GPU defaults - AUTO-DETECTED by hardware compatibility module
    gpu = {
      detection = "auto";            # Auto-detected by hardware compatibility module
    };
    enableOpenGL = true;             # OpenGL support enabled
    enable32BitOpenGL = true;        # 32-bit OpenGL for compatibility
    
    # Hardware compatibility defaults - ENABLED BY DEFAULT
    compatibility = {
      enable = true;                 # Hardware compatibility enabled by default
      autoDetectKvm = true;          # Auto-detect KVM modules by default  
      autoDetectGpu = true;          # Auto-detect GPU by default
      autoVmOptimizations = true;    # Auto-apply VM optimizations by default
      debug = false;                 # Debug disabled by default
    };
    
    # Virtualization defaults
    enableVirtualization = false;    # Hardware virtualization disabled by default
    enableKVM = true;                # KVM support when virtualization enabled
    enableIOMMU = false;             # IOMMU disabled by default
    
    # Remote desktop defaults
    enableRemoteDesktop = false;     # Remote desktop disabled by default
    enableHardwareAcceleration = false;  # Hardware accel for remote desktop
    
    # Firmware defaults
    enableRedistributableFirmware = true;   # Redistributable firmware enabled
    enableAllFirmware = false;       # All firmware disabled (security)
    enableFirmwareUpdates = true;    # Firmware updates enabled
    
    # Audio hardware defaults
    enableAudio = true;              # Audio support enabled
    audioSystem = "pipewire";        # PipeWire as default audio system
    enableRealtimeAudio = true;      # Realtime audio support
    
    # Input device defaults
    enableTouchpad = true;           # Touchpad support enabled
    touchpadTapping = true;          # Tap-to-click enabled
    touchpadNaturalScrolling = true; # Natural scrolling enabled
    touchpadDisableWhileTyping = true; # Disable while typing
    
    # Power management defaults
    enablePowerManagement = true;    # Power management enabled
    enableTLP = true;                # TLP for laptop power management
    enableThermald = true;           # Thermal management
    
    # Storage defaults
    enableTrim = true;               # SSD TRIM support
    enableSmartMonitoring = true;    # SMART disk monitoring
    
    # Network hardware defaults
    enableWiFi = true;               # WiFi support enabled
    enableBluetooth = true;          # Bluetooth support enabled
    enableEthernet = true;           # Ethernet support enabled
  };

  # Service defaults
  # Default configurations for system services
  services = {
    # SSH defaults
    ssh = {
      enable = true;                 # SSH enabled by default
      port = 22;                     # Standard SSH port
      permitRootLogin = "no";        # Root login disabled
      passwordAuthentication = true; # Password auth enabled (override for security)
      maxAuthTries = 3;              # Maximum authentication attempts
      clientAliveInterval = 300;     # Keep-alive interval
      clientAliveCountMax = 2;       # Maximum keep-alive count
    };

    # Time synchronization defaults
    timeSync = {
      enable = true;                 # Time sync enabled
      servers = [                    # Default NTP servers
        "time.cloudflare.com"
        "time.google.com"
        "pool.ntp.org"
      ];
    };

    # DNS defaults
    dns = {
      enable = true;                 # DNS resolution enabled
      fallbackDns = [                # Fallback DNS servers
        "1.1.1.1"
        "8.8.8.8"
      ];
    };

    # Logging defaults
    logging = {
      maxSize = "2G";                # Maximum log size
      maxRetention = "1month";       # Log retention period
      compression = true;            # Log compression enabled
      forwardToSyslog = false;       # Don't forward to syslog
    };
  };

  # Environment defaults
  # Default environment variables and shell configuration
  environment = {
    # Default applications
    editor = "nano";                 # User-friendly editor
    visual = "nano";                 # Visual editor
    pager = "less";                  # Default pager
    browser = "firefox";             # Default browser
    terminal = "konsole";            # Default terminal (overridden per DE)
    
    # Shell defaults
    defaultShell = "zsh";            # ZSH as default shell
    enableZshCompletion = true;      # ZSH completion enabled
    enableBashCompletion = true;     # Bash completion enabled
    
    # Locale defaults
    language = "en_US.UTF-8";        # English language
    timeFormat = "24";               # 24-hour time format
    dateFormat = "iso";              # ISO date format
    
    # XDG defaults
    xdgConfigHome = "$HOME/.config"; # XDG config directory
    xdgDataHome = "$HOME/.local/share"; # XDG data directory
    xdgCacheHome = "$HOME/.cache";   # XDG cache directory
    xdgStateHome = "$HOME/.local/state"; # XDG state directory
  };
}
