# Server Profile - Headless server for containers and virtualization
# Target: Lightweight servers, container hosts, virtualization hosts

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./base.nix
  ];

  # Server profile configuration - extends base profile
  mySystem = {
    # Override hostname default for server systems
    hostname = mkDefault "server";

    # Server features configuration
    features = {
      # No desktop environment for servers
      desktop = {
        enable = mkForce false;
        environment = mkDefault "plasma";
        displayManager = mkDefault "sddm";
        enableWayland = mkDefault false;
        enableX11 = mkDefault false;
        enableRemoteDesktop = mkDefault false;
      };

      # Minimal development tools (for server management)
      development = {
        enable = mkDefault false;
        languages = mkDefault [ "nix" ]; # Only Nix for configuration management
        editors = mkDefault [ "neovim" ];
        enableContainers = mkDefault true;
        enableVirtualization = mkDefault true;
        enableDatabases = mkDefault false; # Databases run in containers
      };

      # Full virtualization support for servers
      virtualization = {
        enable = mkDefault true;
        enableDocker = mkDefault true;
        enablePodman = mkDefault true;
        enableLibvirt = mkDefault true;
        enableVirtualbox = mkDefault false;
        enableWaydroid = mkDefault false;
      };

      # Server-specific features
      server = {
        enable = mkDefault true;
        enableMonitoring = mkDefault true;
        enableBackup = mkDefault true;
        enableWebServer = mkDefault false; # Enable per machine as needed
      };
    };

    # Server-optimized hardware settings
    hardware = {
      kernel = mkDefault "stable"; # LTS kernel for stability
      enableVirtualization = mkDefault true;
      enableRemoteDesktop = mkDefault false;
      gpu = mkDefault "none";
    };
  };

  # Server-specific packages (extends base packages)
  environment.systemPackages = with pkgs; [
    # Container management (additional to base)
    docker-compose
    podman-compose
    buildah
    skopeo

    # Virtualization management
    qemu_kvm
    libvirt
    virt-viewer

    # System monitoring and management
    iotop
    nethogs
    iftop
    vnstat

    # Network tools
    nmap
    tcpdump
    wireshark-cli
    iperf3
    mtr

    # Security tools
    fail2ban
    lynis
    chkrootkit
    rkhunter

    # Backup and sync
    rsync
    rclone
    borgbackup
    restic

    # Text editors and utilities
    neovim
    tmux
    screen

    # System utilities
    strace
    ltrace

    # Network utilities
    httpie # curl/wget are in base

    # Process management
    supervisor

    # Log management
    logrotate

    # Performance monitoring
    sysstat

    # Container security scanning
    trivy

    # Infrastructure as code
    terraform
    ansible

    # Kubernetes tools (optional)
    kubectl
    helm
    k9s

    # Monitoring tools
    prometheus
    grafana

    # Database clients
    postgresql
    mysql
    redis
  ];

  # Server-specific services (extends base services)
  services = {
    # Enhanced SSH for server management
    openssh.settings = {
      MaxAuthTries = mkDefault 3;
      ClientAliveInterval = mkDefault 300;
      ClientAliveCountMax = mkDefault 2;
      X11Forwarding = mkForce false; # Disabled for servers
    };

    # Fail2ban for intrusion prevention
    fail2ban = {
      enable = mkDefault true;
      maxretry = mkDefault 3;
      bantime = mkDefault "1h";
      bantime-increment = {
        enable = mkDefault true;
        multipliers = "1 2 4 8 16 32 64";
        maxtime = "168h";
        overalljails = true;
      };
      jails = {
        ssh = ''
          enabled = true
          port = ssh
          filter = sshd
          logpath = /var/log/auth.log
          maxretry = 3
          bantime = 3600
        '';
      };
    };

    # System monitoring
    prometheus = {
      enable = mkDefault false; # Can be enabled per machine
      port = mkDefault 9090;
      exporters = {
        node = {
          enable = mkDefault true;
          enabledCollectors = [
            "systemd"
            "textfile"
            "filesystem"
            "meminfo"
            "diskstats"
            "netdev"
          ];
        };
      };
    };

    # Log management (extends base journald)
    journald.extraConfig = ''
      SystemMaxUse=2G
      MaxRetentionSec=1month
      Compress=yes
      ForwardToSyslog=no
    '';

    # Network time synchronization (enhanced from base)
    timesyncd.servers = [
      "time.cloudflare.com"
      "time.google.com"
      "pool.ntp.org"
    ];

  };

  # Server-specific networking (extends base networking)
  networking = {
    # Disable WiFi and Bluetooth for servers
    networkmanager.enable = mkForce false;
    wireless.enable = mkForce false;

    # Server firewall rules
    firewall = {
      allowedTCPPorts = [
        80    # HTTP
        443   # HTTPS
        2376  # Docker daemon (if needed)
        9090  # Prometheus (if enabled)
      ];
    };
  };

  # Server-optimized kernel parameters (extends base)
  boot.kernelParams = [
    # Performance and stability
    "transparent_hugepage=madvise"
    "numa_balancing=enable"

    # Security
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
    "page_alloc.shuffle=1"
  ];

  # Server-specific kernel settings
  boot.kernel.sysctl = {
    # Memory management for servers
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;

    # File system
    "fs.file-max" = 2097152;
    "fs.nr_open" = 1048576;
  };

  # Server user configuration (extends base user)
  users.users.${config.mySystem.user} = {
    packages = with pkgs; [
      # Server-specific user packages
      docker-compose
      restic
    ];

    # Additional groups for server functionality
    extraGroups = [
      "systemd-journal" # For log access
    ];
  };

  # No swap for servers (use zram if needed)
  swapDevices = mkDefault [];

  # Optional zram for memory pressure
  zramSwap = {
    enable = mkDefault false; # Disabled by default for servers
    algorithm = "zstd";
    memoryPercent = 10; # Very conservative
  };

  # Server-optimized power management
  powerManagement = {
    enable = mkDefault true;
    cpuFreqGovernor = mkDefault "performance";
  };

  # Disable unnecessary services for servers
  services = {
    # Disable desktop services
    xserver.enable = mkForce false;
    pipewire.enable = mkForce false;

    # Disable power management services
    tlp.enable = mkForce false;
    thermald.enable = mkForce false;
  };

  # Disable audio completely for servers
  hardware.pulseaudio.enable = mkForce false;

  # Enable automatic security updates for servers
  system.autoUpgrade = {
    enable = mkDefault true;
    dates = mkDefault "04:00";
    allowReboot = mkDefault false; # Manual reboot for servers
  };
}
