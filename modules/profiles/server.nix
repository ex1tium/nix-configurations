# Server Profile - Headless server for containers and virtualization
# Target: Lightweight servers, container hosts, virtualization hosts

{ config, lib, pkgs, globalConfig, profileConfig, finalFeatures, ... }:

with lib;

{
  imports = [
    ../nixos/core.nix
    ../nixos/users.nix
    ../nixos/networking.nix
    ../nixos/security.nix
    ../nixos/virtualization.nix
  ];

  # Server profile configuration
  mySystem = {
    enable = true;
    
    # Basic system settings
    hostname = mkDefault "server";
    user = globalConfig.defaultUser;
    timezone = globalConfig.defaultTimezone;
    locale = globalConfig.defaultLocale;
    stateVersion = globalConfig.defaultStateVersion;

    # Server profile features
    features = finalFeatures;

    # No desktop environment for servers
    desktop = {
      enable = false;
    };

    # Minimal development tools (for server management)
    development = {
      enable = mkDefault false;
      languages = mkDefault [ "nix" ]; # Only Nix for configuration management
      editors = [ "neovim" ];
      enableContainers = true;
      enableVirtualization = true;
      enableDatabases = false; # Databases run in containers
    };

    # Full virtualization support
    virtualization = {
      enable = true;
      enableDocker = true;
      enablePodman = true;
      enableLibvirt = true;
      enableVirtualbox = false;
      enableWaydroid = false;
    };

    # Enhanced security for server environments
    security = {
      enable = true;
      enableHardening = true;
      enableSecretsManagement = true;
      enableAuditd = true; # Important for servers
      enableAppArmor = true;
    };

    # Server-optimized networking
    networking = {
      enable = true;
      enableWifi = false; # Servers typically use wired connections
      enableBluetooth = false;
      enableFirewall = true;
      enableAvahi = false; # Disable service discovery for security
      openPorts = [
        22    # SSH
        80    # HTTP
        443   # HTTPS
        2376  # Docker daemon (if needed)
        16443 # Kubernetes API (if needed)
      ];
    };
  };

  # Server-specific packages
  environment.systemPackages = with pkgs; [
    # Container management
    docker
    docker-compose
    podman
    podman-compose
    buildah
    skopeo
    
    # Virtualization management
    qemu_kvm
    libvirt
    virt-manager
    virt-viewer
    
    # System monitoring and management
    htop
    btop
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
    
    # Text editors and utilities
    neovim
    tmux
    screen
    
    # System utilities
    lsof
    strace
    ltrace
    
    # Modern CLI tools
    bat
    eza
    fd
    ripgrep
    fzf
    zoxide
    
    # File compression
    zip
    unzip
    p7zip
    
    # Network utilities
    curl
    wget
    httpie
    
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
  ];

  # Server-specific services
  services = {
    # Enhanced SSH for server management
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true; # Allow password auth for initial setup
        PermitRootLogin = "no";
        X11Forwarding = false;
        AllowUsers = [ config.mySystem.user ];
        MaxAuthTries = 3;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
      openFirewall = true;
    };

    # Fail2ban for intrusion prevention
    fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
      bantime-increment = {
        enable = true;
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
      port = 9090;
      exporters = {
        node = {
          enable = true;
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

    # Log management
    journald = {
      extraConfig = ''
        SystemMaxUse=2G
        MaxRetentionSec=1month
        Compress=yes
        ForwardToSyslog=no
      '';
    };

    # Automatic security updates
    unattended-upgrades = {
      enable = mkDefault true;
    };

    # Network time synchronization
    timesyncd = {
      enable = true;
      servers = [
        "time.cloudflare.com"
        "time.google.com"
        "pool.ntp.org"
      ];
    };

    # Container runtime
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" "--volumes" ];
      };
      
      # Production Docker daemon settings
      daemon.settings = {
        log-driver = "journald";
        log-opts = {
          max-size = "10m";
          max-file = "3";
        };
        storage-driver = "overlay2";
        live-restore = true;
        userland-proxy = false;
        no-new-privileges = true;
        icc = false; # Disable inter-container communication by default
        default-ulimits = {
          nofile = {
            name = "nofile";
            hard = 64000;
            soft = 64000;
          };
        };
      };
    };

    # Podman for rootless containers
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" "--volumes" ];
      };
    };
  };

  # Server-optimized kernel
  boot.kernelPackages = mkDefault pkgs.linuxPackages; # LTS for stability

  # Server-optimized kernel parameters
  boot.kernelParams = [
    # Performance and stability
    "transparent_hugepage=madvise"
    "numa_balancing=enable"
    
    # Security
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
    "page_alloc.shuffle=1"
    
    # Disable unnecessary features
    "quiet"
    "loglevel=3"
  ];

  # Server-specific kernel modules
  boot.kernelModules = [
    "kvm-intel" # or "kvm-amd"
    "vfio-pci"
    "br_netfilter" # For container networking
  ];

  # Enhanced security kernel settings
  boot.kernel.sysctl = {
    # Network security
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    
    # Memory management for servers
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    
    # File system
    "fs.file-max" = 2097152;
    "fs.nr_open" = 1048576;
    
    # Network performance
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 12582912 134217728";
    "net.ipv4.tcp_wmem" = "4096 12582912 134217728";
    "net.core.netdev_max_backlog" = 5000;
  };

  # Server user configuration
  users.users.${config.mySystem.user} = {
    extraGroups = [
      "docker"
      "podman"
      "libvirtd"
      "kvm"
      "systemd-journal" # For log access
    ];
    
    # Minimal server packages
    packages = with pkgs; [
      # Monitoring dashboards
      grafana
      
      # Container orchestration
      docker-compose
      
      # Backup tools
      restic
    ];
  };

  # Server-specific systemd configuration
  systemd = {
    # Faster boot and shutdown
    extraConfig = ''
      DefaultTimeoutStopSec=30s
      DefaultTimeoutStartSec=30s
    '';
    
    # Container auto-start services
    services = {
      container-cleanup = {
        description = "Clean up unused containers and images";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.docker}/bin/docker system prune -af --volumes";
        };
      };
    };
    
    timers = {
      container-cleanup = {
        description = "Clean up containers weekly";
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
        };
        wantedBy = [ "timers.target" ];
      };
    };
  };

  # No swap for servers (use zram if needed)
  swapDevices = [];
  
  # Optional zram for memory pressure
  zramSwap = {
    enable = mkDefault false; # Disabled by default for servers
    algorithm = "zstd";
    memoryPercent = 10; # Very conservative
  };

  # Server-optimized power management
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
  };

  # Disable unnecessary services for servers
  services = {
    # Disable desktop services
    xserver.enable = false;
    pipewire.enable = false;
    pulseaudio.enable = false;
    
    # Disable power management services
    tlp.enable = false;
    thermald.enable = false;
  };

  # Enable automatic security updates
  system.autoUpgrade = {
    enable = mkDefault true;
    dates = "04:00";
    allowReboot = false; # Manual reboot for servers
    channel = "https://nixos.org/channels/nixos-24.11";
  };
}
