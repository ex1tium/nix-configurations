# Modern Configuration for 'elara' machine
# Developer workstation with full capabilities
# Uses the developer profile with automatic hardware detection

{ pkgs, ... }:

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
        # Enable virtualization for development
        enableDocker = true;
        enablePodman = false; # Disabled to avoid conflict with Docker
        enableLibvirt = true;
        enableKvmNested = true; # Enable nested virtualization
      };
    };

    # Machine-specific hardware settings
    hardware = {
      kernel = "latest"; # Use latest kernel for development
      enableVirtualization = true;
      enableRemoteDesktop = true;

      # Use the new nested structure for GPU detection.
      gpu = {
        detection = "auto"; # Use auto-detection by default
      };

      # Point to the machine-specific hardware facts file.
      facterFile = ./facter.json;

      # Enhanced hardware detection debug mode for testing/validation
      debug = true;

    };
  };

  # Enable microcode updates for the CPU
  hardware.cpu.intel.updateMicrocode = true;

  # Performance optimizations for VM
  boot = {
    kernelParams = [
      "elevator=noop" # Better for VMs
      "intel_idle.max_cstate=1" # Better VM performance
    ];
    loader.timeout = 1;
  };

  # Machine-specific Nix settings
  nix.settings = {
    cores = 4; # Number of cores for building
    max-jobs = "auto";
  };

  # Machine-specific packages (using shared collections)
  environment.systemPackages =
    let
      packages = import ../../modules/packages/common.nix { inherit pkgs; };
    in
    packages.vmTools;

  # Enforce startup order to prevent xrdp/sddm deadlock
  systemd.services.xrdp.after = [ "display-manager.service" ];

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
}
