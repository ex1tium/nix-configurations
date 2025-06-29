# Low-Spec Desktop Template
# Optimized for older hardware with XFCE desktop environment
# Copy this file to machines/{hostname}/configuration.nix and customize

{ lib, pkgs, ... }:

with lib;

{
  # Machine-specific overrides for low-spec desktop systems
  mySystem = {
    # Machine-specific settings (CUSTOMIZE THESE)
    hostname = "CHANGE-ME";  # Set your machine hostname

    # Desktop features optimized for low-spec hardware
    features = {
      desktop = {
        enable = true;
        environment = "xfce";             # XFCE for low-spec machines
        lowSpec = true;                   # Enable low-spec optimizations
        enableRemoteDesktop = mkDefault false;
        enableWayland = mkDefault false;  # X11 only for better compatibility
        enableX11 = mkDefault true;
      };

      # Minimal development tools (optional)
      development = {
        enable = mkDefault false;         # Disable by default for performance
        languages = mkDefault [ "nix" ];  # Only Nix for system management
        editors = mkDefault [ "vim" ];    # Lightweight editors only
      };

      # Disable virtualization for performance
      virtualization = {
        enable = mkDefault false;
      };

      # Server features disabled
      server = {
        enable = mkDefault false;
      };
    };

    # Hardware settings optimized for older machines
    hardware = {
      kernel = mkDefault "stable";        # Stable kernel for reliability
      enableVirtualization = mkDefault false;
      enableRemoteDesktop = mkDefault false;
      gpu = mkDefault "none";             # Set to "intel", "amd" based on hardware
    };
  };

  # Performance optimizations for low-spec hardware
  nix.settings = {
    cores = mkDefault 1;                  # Limit build cores
    max-jobs = mkDefault 1;               # Single job to avoid memory pressure
  };

  # Minimal additional packages
  environment.systemPackages = with pkgs; [
    # Essential applications only
    firefox                              # Web browser
    libreoffice-fresh                    # Office suite
    
    # Lightweight alternatives
    mousepad                             # Text editor
    ristretto                            # Image viewer
    mpv                                  # Video player
    
    # System utilities
    htop                                 # System monitor
    gparted                              # Partition manager
  ];

  # Memory and performance optimizations
  boot = {
    # Kernel parameters for low-spec systems
    kernelParams = [
      "quiet"                            # Reduce boot messages
      "mitigations=off"                  # Disable CPU mitigations for performance
      "nohz=on"                          # Reduce timer interrupts
      "rcu_nocbs=0-7"                    # Reduce RCU overhead
    ];

    # Faster boot
    loader.timeout = mkDefault 1;
    
    # Kernel optimizations
    kernel.sysctl = {
      # Memory management for low RAM
      "vm.swappiness" = 60;              # Use swap more aggressively
      "vm.vfs_cache_pressure" = 100;     # Standard cache pressure
      "vm.dirty_ratio" = 10;             # Lower dirty ratio
      "vm.dirty_background_ratio" = 3;   # Lower background ratio
      
      # Network optimizations
      "net.core.rmem_max" = 16777216;    # Reduce network buffers
      "net.core.wmem_max" = 16777216;
    };
  };

  # Hardware optimizations
  hardware = {
    # Disable unnecessary hardware support
    enableRedistributableFirmware = mkDefault true;
    enableAllFirmware = mkDefault false;
    
    # Audio optimization
    pulseaudio.enable = mkForce false;
    
    # Bluetooth disabled by default
    bluetooth.enable = mkDefault false;
  };

  # Service optimizations
  services = {
    # Disable heavy services
    packagekit.enable = mkForce false;
    flatpak.enable = mkForce false;
    locate.enable = mkForce false;
    
    # Optimize journald for low storage
    journald.extraConfig = ''
      SystemMaxUse=100M
      MaxRetentionSec=1week
      Compress=yes
    '';
    
    # Aggressive power management
    tlp = {
      enable = mkDefault true;
      settings = {
        # CPU scaling
        CPU_SCALING_GOVERNOR_ON_AC = "ondemand";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 80;         # Limit max performance
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 50;
        
        # Disk optimization
        DISK_APM_LEVEL_ON_AC = "128";
        DISK_APM_LEVEL_ON_BAT = "1";
        
        # Network power saving
        WIFI_PWR_ON_AC = "on";
        WIFI_PWR_ON_BAT = "on";
        
        # USB power saving
        USB_AUTOSUSPEND = "1";
      };
    };
    
    # Disable thermald for older systems
    thermald.enable = mkForce false;
  };

  # Networking optimizations
  networking = {
    # Disable IPv6 for simplicity
    enableIPv6 = mkDefault false;
    
    # Firewall optimization
    firewall = {
      enable = mkDefault true;
      allowPing = mkDefault true;
      allowedTCPPorts = mkDefault [ 22 ];  # SSH only
    };
  };

  # Memory optimization with zram
  zramSwap = {
    enable = mkDefault true;
    algorithm = "lz4";                   # Fast compression
    memoryPercent = mkDefault 25;        # Conservative for low RAM
  };

  # Disable swap files for SSD longevity
  swapDevices = mkDefault [];

  # Font optimization (fewer fonts)
  fonts.packages = with pkgs; [
    noto-fonts
    liberation_ttf
    dejavu_fonts
  ];

  # User configuration
  users.users.${config.mySystem.user} = {
    # Minimal user packages
    packages = with pkgs; [
      # Only essential user applications
    ];
  };

  # Disable documentation to save space
  documentation = {
    enable = mkDefault false;
    nixos.enable = mkDefault false;
    man.enable = mkDefault true;         # Keep man pages
    info.enable = mkDefault false;
    doc.enable = mkDefault false;
  };

  # Automatic cleanup
  nix.gc = {
    automatic = mkDefault true;
    dates = mkDefault "daily";
    options = mkDefault "--delete-older-than 3d";  # Aggressive cleanup
  };

  # Optimize Nix store
  nix.optimise = {
    automatic = mkDefault true;
    dates = mkDefault [ "weekly" ];
  };
}

# LOW-SPEC CUSTOMIZATION CHECKLIST:
# [ ] Set hostname in mySystem.hostname
# [ ] Configure GPU type in mySystem.hardware.gpu (if any)
# [ ] Adjust memory settings based on available RAM
# [ ] Test performance and adjust kernel parameters
# [ ] Consider enabling development features only if needed
# [ ] Monitor resource usage and optimize further if needed
