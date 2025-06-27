# Virtualization Feature Module
# Implements container and virtualization support when enabled

{ config, lib, pkgs, ... }:

with lib;

{
  config = mkIf config.mySystem.features.virtualization.enable {
    # Docker configuration
    virtualisation.docker = {
      enable = mkDefault true;
      enableOnBoot = mkDefault true;
      autoPrune = {
        enable = mkDefault true;
        dates = mkDefault "weekly";
        flags = [ "--all" "--volumes" ];
      };
      
      # Docker daemon settings
      daemon.settings = {
        # Logging
        log-driver = "journald";
        log-opts = {
          max-size = "10m";
          max-file = "3";
        };
        
        # Storage
        storage-driver = "overlay2";
        
        # Performance
        live-restore = true;
        userland-proxy = false;
        
        # Security
        no-new-privileges = true;
        icc = false;  # Disable inter-container communication by default
        
        # Resource limits
        default-ulimits = {
          nofile = {
            name = "nofile";
            hard = 64000;
            soft = 64000;
          };
          nproc = {
            name = "nproc";
            hard = 4096;
            soft = 4096;
          };
        };
        
        # Registry mirrors (optional)
        registry-mirrors = [];
        
        # Insecure registries (for development)
        insecure-registries = [];
      };
    };

    # Podman configuration (rootless containers)
    virtualisation.podman = {
      enable = mkDefault true;
      dockerCompat = mkIf (!config.virtualisation.docker.enable) (mkDefault true);  # Only if Docker is disabled
      dockerSocket.enable = mkIf (!config.virtualisation.docker.enable) (mkDefault true);
      defaultNetwork.settings.dns_enabled = true;
      
      autoPrune = {
        enable = mkDefault true;
        dates = mkDefault "weekly";
        flags = [ "--all" "--volumes" ];
      };
    };

    # libvirt/KVM configuration
    virtualisation.libvirtd = {
      enable = mkDefault true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;  # TPM emulation
        ovmf = {
          enable = true;      # UEFI support
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };

    # QEMU configuration
    virtualisation.spiceUSBRedirection.enable = mkDefault true;

    # VirtualBox removed - conflicts with KVM and not needed
    # Use QEMU/KVM for full virtualization instead

    # Waydroid for Android apps (optional)
    virtualisation.waydroid.enable = mkDefault false;

    # LXC/LXD containers (enabled by default for lightweight containers)
    virtualisation.lxc.enable = mkDefault true;
    virtualisation.lxd.enable = mkDefault true;  # LXD support

    # Container and virtualization packages
    environment.systemPackages = with pkgs; [
      # Docker tools
      docker
      docker-compose
      docker-buildx
      
      # Podman tools
      podman
      podman-compose
      buildah
      skopeo
      
      # Container security
      trivy           # Vulnerability scanner
      dive            # Docker image analyzer
      
      # Kubernetes tools
      kubectl
      helm
      k9s
      kubectx
      
      # Virtualization management
      virt-manager
      virt-viewer
      libvirt
      qemu_kvm
      
      # SPICE tools
      spice-gtk
      spice-protocol
      
      # Network tools for containers
      bridge-utils
      iptables
      
      # Container development
      lazydocker      # Docker TUI
      ctop            # Container top
      
      # Image building
      kaniko          # Container image builder
      buildkit        # Advanced build features

      # LXC/LXD tools
      lxc             # LXC container tools
      lxd             # LXD daemon and client
    ] ++ optionals config.mySystem.features.desktop.enable [
      # GUI tools
      virt-manager
      # gnome-boxes not available in current nixpkgs
    ];

    # User groups for virtualization
    users.users.${config.mySystem.user}.extraGroups = [
      "docker"
      "podman"
      "libvirtd"
      "kvm"
      "qemu-libvirtd"
      "lxd"           # LXD access
    ];

    # Ensure virtualization groups exist
    users.groups = {
      docker = {};
      podman = {};
      libvirtd = {};
      kvm = {};
      qemu-libvirtd = {};
      lxd = {};       # LXD group
    };

    # Kernel modules for virtualization
    boot.kernelModules = [
      "kvm-intel"     # Intel KVM support
      "kvm-amd"       # AMD KVM support
      "vfio-pci"      # VFIO for GPU passthrough
      "vhost-net"     # Network acceleration
      "br_netfilter"  # Bridge netfilter for containers
      "overlay"       # Overlay filesystem for containers
    ];

    # Kernel parameters for virtualization
    boot.kernelParams = [
      # Enable IOMMU for GPU passthrough
      "intel_iommu=on"
      "amd_iommu=on"
      
      # Hugepages for better VM performance
      "transparent_hugepage=madvise"
      
      # Container networking
      "systemd.unified_cgroup_hierarchy=1"
    ];

    # Sysctl settings for containers and VMs
    boot.kernel.sysctl = {
      # Container networking
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      
      # VM memory management
      "vm.max_map_count" = 262144;
      "vm.overcommit_memory" = 1;
      
      # File system limits for containers
      "fs.inotify.max_user_watches" = 1048576;
      "fs.inotify.max_user_instances" = 8192;
      
      # Network performance
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.ipv4.tcp_rmem" = "4096 12582912 134217728";
      "net.ipv4.tcp_wmem" = "4096 12582912 134217728";
      "net.core.netdev_max_backlog" = 5000;
    };

    # Firewall configuration for virtualization
    networking.firewall = {
      # Docker and container networking
      trustedInterfaces = [
        "docker0"
        "podman0"
        "virbr0"
        "br-+"      # Docker bridge networks
      ];
      
      # Ports for virtualization services
      allowedTCPPorts = [
        # Docker daemon (if remote access needed)
        # 2376    # Docker daemon TLS
        # 2377    # Docker swarm
        
        # Kubernetes (if needed)
        # 6443    # Kubernetes API
        # 10250   # Kubelet
        
        # libvirt
        # 16509   # libvirt TLS
        # 5900-5999  # VNC range
      ];
      
      allowedUDPPorts = [
        # DHCP for VMs
        # 67      # DHCP server
        # 68      # DHCP client
      ];
    };

    # Systemd services for virtualization
    systemd.services = {
      # Docker service optimization
      docker.serviceConfig = {
        ExecStart = mkForce [
          ""  # Clear the default
          "${pkgs.docker}/bin/dockerd --host=fd:// --containerd=/run/containerd/containerd.sock"
        ];
        ExecReload = "${pkgs.util-linux}/bin/kill -s HUP $MAINPID";
        TimeoutStartSec = "0";
        RestartSec = "2";
        Restart = "always";
        
        # Security
        NoNewPrivileges = true;
        KillMode = "process";
        Delegate = true;
        Type = "notify";
        
        # Resource limits
        LimitNOFILE = 1048576;
        LimitNPROC = 1048576;
        LimitCORE = "infinity";
        TasksMax = "infinity";
      };
      
      # Podman socket is automatically configured by NixOS when dockerSocket.enable = true
    };

    # Container runtime configuration
    # Note: NixOS handles container policy and registries automatically
    # Custom configurations can be added per-machine if needed

    # Development environment variables for containers
    environment.sessionVariables = {
      # Docker
      DOCKER_BUILDKIT = "1";
      COMPOSE_DOCKER_CLI_BUILD = "1";
      
      # Podman
      DOCKER_HOST = mkIf config.virtualisation.podman.dockerSocket.enable "unix:///run/podman/podman.sock";
      
      # Container development
      BUILDKIT_PROGRESS = "plain";
      
      # Kubernetes
      KUBECONFIG = "$HOME/.kube/config";
    };

    # Virtualization-specific shell aliases
    environment.shellAliases = {
      # Docker shortcuts
      d = "docker";
      dc = "docker-compose";
      dps = "docker ps";
      di = "docker images";
      dex = "docker exec -it";
      dlog = "docker logs -f";
      
      # Podman shortcuts
      p = "podman";
      pc = "podman-compose";
      pps = "podman ps";
      pi = "podman images";
      pex = "podman exec -it";
      plog = "podman logs -f";
      
      # Kubernetes shortcuts
      k = "kubectl";
      kgp = "kubectl get pods";
      kgs = "kubectl get services";
      kgd = "kubectl get deployments";
      kdesc = "kubectl describe";
      klog = "kubectl logs -f";
      
      # VM shortcuts
      vms = "virsh list --all";
      vmstart = "virsh start";
      vmstop = "virsh shutdown";
    };
  };
}
