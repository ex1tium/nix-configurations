# Modern Configuration for 'elara' machine
# Developer workstation with full capabilities
# Migrated to use modern machine profile system

{ config, lib, pkgs, globalConfig, profileConfig, finalFeatures, ... }:

with lib;

{
  # Import hardware and profile configurations
  imports = [
    # Hardware-specific configuration (automatically generated)
    ./hardware-configuration.nix

    # Modern profile system handles the rest
    # Profile is specified in flake.nix machines configuration
  ];

  # Modern system configuration using profile system
  mySystem = {
    enable = true;

    # Machine-specific settings (override profile defaults)
    hostname = "elara";
    user = globalConfig.defaultUser;

    # Use developer profile features with machine-specific overrides
    features = finalFeatures // {
      # Machine-specific feature overrides
      virtualization.enable = true;
      development.enable = true;
      desktop.enable = true;
    };

    # Machine-specific hardware settings
    hardware = {
      kernel = "latest"; # Use latest kernel for development
      enableVirtualization = true;
      enableRemoteDesktop = true;
    };
  };

  # Machine-specific Nix settings
  nix.settings = {
    cores = 4; # Number of cores for building
    max-jobs = "auto";
  };

  # Machine-specific packages (beyond profile defaults)
  environment.systemPackages = with pkgs; [
    # Development tools specific to this machine
    direnv                 # Directory environment manager
    nixd                   # Modern Nix language server

    # VM-specific tools
    spice-vdagent         # SPICE guest agent
    qemu-guest-agent      # QEMU guest agent
  ];

  # Enable programs for development
  programs = {
    # Run unpatched dynamic binaries (needed for VS Code Remote, etc.)
    nix-ld.enable = true;

    # Enable Firefox browser
    firefox.enable = true;
  };

  # Virtual Machine Services (elara is a VM)
  services = {
    # QEMU guest agent for better VM integration
    qemuGuest.enable = true;

    # SPICE agent for clipboard sharing and resolution handling
    spice-vdagentd.enable = true;

    # Remote Desktop Configuration
    xrdp = {
      enable = true;
      # Use KDE Plasma with X11 as the default session
      defaultWindowManager = "startplasma-x11";
      openFirewall = true;
    };
  };

  # Machine-specific user configuration
  users.users.${globalConfig.defaultUser} = {
    # Additional packages specific to this machine
    packages = with pkgs; [
      kdePackages.kate      # KDE text editor

      # Development tools for this specific machine
      jetbrains.idea-ultimate

      # VM-specific applications
      virt-manager
    ];
  };

  # Machine-specific networking
  networking = {
    hostName = "elara";

    # Open additional ports for development
    firewall.allowedTCPPorts = [
      3389  # RDP
      5900  # VNC
    ];
  };

  # Performance optimizations for VM
  boot = {
    # VM-optimized kernel parameters
    kernelParams = [
      "elevator=noop"  # Better for VMs
      "intel_idle.max_cstate=1"  # Better VM performance
    ];

    # Faster boot for development
    loader.timeout = 1;
  };

  # VM-specific hardware optimizations
  hardware = {
    # Enable KVM nested virtualization if supported
    cpu.intel.updateMicrocode = true;
  };
}
