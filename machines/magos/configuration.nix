# Machine configuration for 'magos'
# Desktop machine with dual-boot Windows 11 (AtlasOS) + NixOS
# Hardware: 128 GB UFS/eUFS, Intel CPU, Btrfs with zram + swap
# Uses the desktop profile with machine-specific overrides

{ pkgs, lib, ... }:

{
  # Machine-specific settings
  mySystem = {
    hostname = "magos";

    # Developer profile features (inherits desktop + development + virtualization)
    features = {
      desktop = {
        # Use KDE Plasma 6 as primary desktop environment
        environment = "plasma";
        enableRemoteDesktop = false; # Not a VM, disable RDP
      };

      # Development tools enabled for this development machine
      development = {
        languages = [ "nodejs" "go" "python" "rust" "nix" "java" ];
      };

      # Virtualization enabled for development
      virtualization = {
        enableDocker = true;
        enablePodman = false; # Disabled to avoid conflict with Docker
        enableLibvirt = true;
        enableKvmNested = false; # Not nested, physical machine
      };
    };

    # Hardware settings for UFS/eUFS device
    hardware = {
      kernel = "latest"; # Use latest kernel for better UFS support
      enableVirtualization = true; # Enable for development (Docker, libvirt)
      enableRemoteDesktop = false;

      gpu = {
        detection = "auto"; # Auto-detect GPU
      };

      debug = false;
    };
  };

  # Intel CPU microcode updates
  hardware.cpu.intel.updateMicrocode = true;

  # Boot configuration for dual-boot with Windows
  boot = {
    # Timeout for boot menu (allows Windows selection)
    loader.timeout = 3;

    # Kernel parameters optimized for UFS/eUFS and battery life
    kernelParams = [
      "quiet"
      "loglevel=3"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"
      "no_console_suspend" # Prevent suspend during console operations
      "intel_idle.max_cstate=1" # Disable deep C-states (fixes i3-N305 freeze)
      "processor.max_cstate=1" # Disable ACPI C-states
    ];
  };

  # Nix settings for this machine
  nix.settings = {
    cores = 4;
    max-jobs = "auto";
  };

  # Networking configuration
  networking = {
    # Enable NetworkManager for easy WiFi/Ethernet management
    networkmanager.enable = true;

    # Firewall configuration
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 ]; # SSH only
    };
  };

  # Time and locale (inherited from base profile, but can override)
  time.timeZone = lib.mkDefault "Europe/Helsinki";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Keyboard layout
  services.xserver.xkb.layout = lib.mkDefault "fi";

  # Power management for battery-friendly operation
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
      USB_AUTOSUSPEND = 1;
      USB_AUTOSUSPEND_USBHID = 1;
    };
  };

  # Disable hibernation to avoid NTFS dirty state in dual-boot
  # (Windows hibernation can cause issues when dual-booting)
  systemd.sleep.extraConfig = ''
    AllowHibernation=no
    AllowSuspendThenHibernate=no
  '';

  # Btrfs maintenance
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # Weekly fstrim for SSD optimization
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # Snapper for Btrfs snapshots
  services.snapper = {
    cleanupInterval = "3h";

    configs = {
      root = {
        SUBVOLUME = "/";
        FSTYPE = "btrfs";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 10;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 4;
        TIMELINE_LIMIT_MONTHLY = 3;
        TIMELINE_LIMIT_YEARLY = 1;
      };

      home = {
        SUBVOLUME = "/home";
        FSTYPE = "btrfs";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 5;
        TIMELINE_LIMIT_DAILY = 3;
        TIMELINE_LIMIT_WEEKLY = 2;
        TIMELINE_LIMIT_MONTHLY = 1;
      };
    };
  };

  # zram swap configuration (50% of RAM, zstd compression, high priority)
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100;
  };

  # Journald configuration to limit disk writes
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=500M
    RuntimeMaxUse=100M
    MaxRetentionSec=30day
  '';

  # SSH for remote management
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    openFirewall = true;
  };
}

