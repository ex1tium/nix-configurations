# Server Template
# Minimal headless server configuration following container-first philosophy
# Copy this file to machines/{hostname}/configuration.nix and customize

{ lib, pkgs, ... }:

with lib;

{
  # Machine-specific overrides for the server profile
  mySystem = {
    # Machine-specific settings (CUSTOMIZE THESE)
    hostname = "CHANGE-ME";  # Set your server hostname

    # Server features (minimal by default)
    features = {
      # No desktop environment
      desktop = {
        enable = mkForce false;
      };

      # Minimal development tools (only if needed)
      development = {
        enable = mkDefault false;         # Enable only if this server needs dev tools
        languages = mkDefault [ "nix" ];  # Only Nix for system management
        editors = mkDefault [ "vim" ];    # Minimal editor
      };

      # Full virtualization support for containers
      virtualization = {
        enable = mkDefault true;
        enableDocker = mkDefault true;
        enablePodman = mkDefault true;
        enableLibvirt = mkDefault true;   # For VMs if needed
      };

      # Server-specific features
      server = {
        enable = mkDefault true;
        enableMonitoring = mkDefault false;  # Use containers for monitoring
        enableBackup = mkDefault true;       # Enable backup tools
        enableWebServer = mkDefault false;   # Use containers for web servers
      };
    };

    # Server hardware settings
    hardware = {
      kernel = mkDefault "stable";        # Stable kernel for reliability
      enableVirtualization = mkDefault true;
      enableRemoteDesktop = mkDefault false;
      gpu = mkDefault "none";             # Servers typically don't need GPU
    };
  };

  # Server-specific Nix settings
  nix.settings = {
    cores = mkDefault 0;                  # Use all available cores
    max-jobs = mkDefault "auto";
  };

  # Machine-specific packages (add only what's needed)
  environment.systemPackages = with pkgs; [
    # Add server-specific packages here
    # Examples (uncomment as needed):
    
    # Infrastructure as Code (if this server manages infrastructure)
    # terraform
    # ansible
    
    # Kubernetes tools (if this server manages k8s)
    # kubectl
    # helm
    # k9s
    
    # Additional monitoring (if not using containers)
    # prometheus-node-exporter  # Enable via services instead
    
    # Additional backup tools
    # rclone
    # restic
    
    # Database clients (if needed for administration)
    # postgresql  # Use containers for databases themselves
    # mysql
    # redis
    
    # Additional security tools
    # lynis
    # chkrootkit
    # rkhunter
  ];

  # Machine-specific services
  services = {
    # Add machine-specific services here
    # Examples:
    
    # Node exporter for monitoring (if using Prometheus)
    # prometheus.exporters.node.enable = true;
    
    # Additional backup services
    # borgbackup.repos = {
    #   myrepo = {
    #     path = "/var/lib/backup";
    #     authorizedKeys = [ "ssh-ed25519 AAAA..." ];
    #   };
    # };
    
    # Custom web services (prefer containers)
    # nginx.enable = false;  # Use containers instead
  };

  # Machine-specific networking
  networking = {
    # Add machine-specific networking here
    firewall.allowedTCPPorts = [
      # Add ports as needed
      # 80    # HTTP (if running web services)
      # 443   # HTTPS
      # 5432  # PostgreSQL (if exposing database)
      # 3000  # Grafana (if running monitoring)
      # 9090  # Prometheus
    ];
    
    firewall.allowedUDPPorts = [
      # Add UDP ports as needed
    ];
  };

  # Server optimizations
  boot = {
    # Server-specific kernel parameters
    kernelParams = [
      # Performance optimizations
      "transparent_hugepage=madvise"
      "numa_balancing=enable"
      
      # Security hardening
      "slab_nomerge"
      "init_on_alloc=1"
      "init_on_free=1"
      "page_alloc.shuffle=1"
    ];

    # Faster boot for servers
    loader.timeout = mkDefault 3;
  };

  # Hardware-specific optimizations
  hardware = {
    # Enable based on actual hardware
    # cpu.intel.updateMicrocode = true;   # For Intel CPUs
    # cpu.amd.updateMicrocode = true;     # For AMD CPUs
  };

  # Server-specific user configuration
  users.users.${config.mySystem.user} = {
    # Add server-specific user packages
    packages = with pkgs; [
      # Minimal user packages for server administration
      tmux
      htop
    ];
    
    # Additional groups for server management
    extraGroups = [
      "systemd-journal"  # For log access
      "docker"           # For container management
      "libvirtd"         # For VM management
    ];
  };

  # Container-specific configuration
  virtualisation = {
    # Docker configuration
    docker = {
      enable = mkDefault true;
      autoPrune = {
        enable = mkDefault true;
        dates = mkDefault "weekly";
      };
    };
    
    # Podman configuration
    podman = {
      enable = mkDefault true;
      autoPrune = {
        enable = mkDefault true;
        dates = mkDefault "weekly";
      };
    };
  };

  # Server monitoring (system-level only)
  services = {
    # System monitoring
    journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=1month
      Compress=yes
    '';
    
    # Log rotation
    logrotate = {
      enable = mkDefault true;
      settings = {
        "/var/log/containers/*.log" = {
          frequency = "daily";
          rotate = 7;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
        };
      };
    };
  };

  # Backup configuration
  programs.borgbackup = {
    # Configure borgbackup if needed
    # repos = {
    #   mybackup = {
    #     path = "/var/lib/backup";
    #     # Configure as needed
    #   };
    # };
  };

  # Security hardening
  security = {
    # Additional security measures
    sudo.wheelNeedsPassword = mkDefault true;
    
    # Audit system
    # auditd.enable = true;
  };
}

# SERVER CUSTOMIZATION CHECKLIST:
# [ ] Set hostname in mySystem.hostname
# [ ] Configure firewall ports for your services
# [ ] Add necessary packages for your use case
# [ ] Configure backup strategy
# [ ] Set up monitoring (prefer containers)
# [ ] Configure container services (Docker Compose files)
# [ ] Test container deployment
# [ ] Set up log management
# [ ] Configure security hardening
# [ ] Document your container architecture

# CONTAINER-FIRST REMINDERS:
# - Use Docker Compose for multi-service applications
# - Run databases in containers, not as system services
# - Use containers for monitoring (Prometheus, Grafana)
# - Keep the NixOS system minimal and focused on infrastructure
# - Document all container configurations in your project
