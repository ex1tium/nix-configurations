# Developer Profile - Essential development tools and capabilities
# Target: Work laptops, daily driver machines, development workstations
#
# Design Principle: This profile provides core development capabilities.
# Machine-specific configurations should extend this base profile with
# specialized tools (databases, mobile dev, embedded tools, etc.) as needed.

{ config, lib, pkgs, globalConfig, profileConfig, finalFeatures, ... }:

with lib;

{
  imports = [
    # Inherit all desktop capabilities
    ./desktop.nix
    
    # Add development-specific modules
    ../nixos/development.nix
    ../nixos/virtualization.nix
  ];

  # Developer profile extends desktop with development capabilities
  mySystem = {
    # Development features
    development = {
      enable = true;
      languages = [ "nodejs" "go" "python" "rust" "nix" ];
      editors = [ "vscode" "neovim" ];
      enableContainers = true;
      enableVirtualization = true;
      enableDatabases = true;
    };

    # Enhanced virtualization for development
    virtualization = {
      enable = true;
      enableDocker = true;
      enablePodman = true;
      enableLibvirt = true;
      enableVirtualbox = false; # Conflicts with KVM
      enableWaydroid = false;   # Android development (optional)
    };

    # Enhanced security for development
    security = {
      enableHardening = true;
      enableSecretsManagement = true;
      enableAuditd = false; # Can impact development performance
      enableAppArmor = true;
    };

    # Developer-optimized desktop
    desktop = {
      environment = "plasma"; # KDE Plasma 6 for full-featured experience
      enableRemoteDesktop = true;
    };
  };

  # Essential developer packages
  # Note: Specialized tools (databases, mobile dev, embedded tools, etc.)
  # should be added in machine-specific configurations
  environment.systemPackages = with pkgs; [
    # Core development tools
    vscode-with-extensions
    neovim

    # Version control and collaboration
    git
    gh # GitHub CLI
    git-lfs
    git-crypt

    # Core language runtimes and tools
    # Node.js LTS + essential tooling
    nodejs_latest
    nodePackages.npm
    nodePackages.yarn
    nodePackages.pnpm

    # Go + essential tooling
    go
    gopls
    go-tools
    delve
    golangci-lint

    # Python + essential tooling
    python3
    python3Packages.pip
    python3Packages.poetry
    python3Packages.virtualenv

    # Container tools
    docker-compose
    podman-compose

    # Essential network debugging
    curl
    wget
    httpie

    # Essential build tools
    gnumake
    cmake
    pkg-config

    # Modern development utilities
    jq
    yq
    just # Command runner
    direnv

    # Basic debugging tools
    gdb
    strace

    # Cyberdeck VS Code theme (custom)
    # Will be handled via overlay
  ];

  # Essential development services
  services = {
    # Docker daemon
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune.enable = true;
    };

    # SSH for development
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true; # Allow for development convenience
        PermitRootLogin = "no";
        X11Forwarding = true;
        AllowUsers = [ config.mySystem.user ];
      };
    };
  };

  # Development-optimized kernel
  boot.kernelPackages = mkDefault pkgs.linuxPackages_latest;

  # Enhanced kernel parameters for development
  boot.kernelParams = [
    # Performance
    "mitigations=off" # Disable CPU mitigations for performance (development only)
    
    # Memory
    "transparent_hugepage=madvise"
    
    # Development-friendly
    "systemd.unified_cgroup_hierarchy=1" # For container development
  ];

  # Development-specific kernel modules
  boot.kernelModules = [
    "kvm-intel" # or "kvm-amd"
    "vfio-pci"
  ];

  # Enhanced file system support for development
  boot.supportedFilesystems = [ "ntfs" "exfat" ];

  # Development user configuration
  users.users.${config.mySystem.user} = {
    extraGroups = [
      "docker"
      "podman"
      "libvirtd"
      "kvm"
    ];
    
    packages = with pkgs; [
      # Essential development IDEs (machine-specific tools should be added per machine)
      jetbrains.idea-community # Basic IDE, machines can add Ultimate if needed
    ];
  };

  # Development environment variables
  environment.sessionVariables = {
    # Development paths
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
    
    # Node.js
    NODE_OPTIONS = "--max-old-space-size=8192";
    
    # Development tools
    EDITOR = "code";
    VISUAL = "code";
    BROWSER = "brave";
    
    # Container development
    DOCKER_BUILDKIT = "1";
    COMPOSE_DOCKER_CLI_BUILD = "1";
  };

  # Essential networking for development
  networking.firewall = {
    allowedTCPPorts = [
      # Common development servers (machines can add specific ports as needed)
      3000 # React/Node.js dev server
      8000 # Python dev server
      8080 # Common dev server
    ];
  };



  # Enhanced swap for development workloads
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25; # Less aggressive than desktop
  };

  # Development-optimized power management
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_SCALING_GOVERNOR_ON_BAT = "performance"; # Maintain performance on battery
    CPU_BOOST_ON_AC = 1;
    CPU_BOOST_ON_BAT = 1;
    CPU_HWP_DYN_BOOST_ON_AC = 1;
    CPU_HWP_DYN_BOOST_ON_BAT = 1;
  };

  # Disable automatic updates for development stability
  system.autoUpgrade.enable = false;
}
