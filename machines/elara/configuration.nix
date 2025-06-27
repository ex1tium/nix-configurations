# Modern Configuration for 'elara' machine
# Developer workstation with full capabilities
# Uses the developer profile with machine-specific customizations

{ lib, pkgs, ... }:

with lib;

{
  # Machine-specific overrides for the developer profile
  mySystem = {
    # Machine-specific settings
    hostname = "elara";

    # Machine-specific feature overrides (if needed)
    features = {
      # The developer profile already enables these, but we can override if needed
      desktop = {
        enableRemoteDesktop = true; # Enable for VM access
      };

      development = {
        # Add any machine-specific development languages/tools
        languages = [ "nodejs" "go" "python" "rust" "nix" "java" ];
      };

      virtualization = {
        # Enable all virtualization for development
        enableDocker = true;
        enablePodman = true;
        enableLibvirt = true;
      };
    };

    # Machine-specific hardware settings
    hardware = {
      kernel = "latest"; # Use latest kernel for development
      enableVirtualization = true;
      enableRemoteDesktop = true;
      gpu = "intel"; # Set based on actual hardware
    };
  };

  # Machine-specific Nix settings
  nix.settings = {
    cores = 4; # Number of cores for building
    max-jobs = "auto";
  };

  # Machine-specific packages (beyond profile defaults)
  environment.systemPackages = with pkgs; [
    # VM-specific tools
    spice-vdagent         # SPICE guest agent
    qemu_kvm              # QEMU guest agent
  ];

  # Virtual Machine Services (elara is a VM)
  services = {
    # QEMU guest agent for better VM integration
    qemuGuest.enable = true;

    # SPICE agent for clipboard sharing and resolution handling
    spice-vdagentd.enable = true;

    # Remote Desktop Configuration
    xrdp = {
      enable = true;
      defaultWindowManager = "startplasma-x11";
      openFirewall = true;
    };
  };

  # Machine-specific networking
  networking = {
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
