# Developer Workstation Template
# Copy this file to machines/{hostname}/configuration.nix and customize

{ lib, pkgs, ... }:

with lib;

{
  # Machine-specific overrides for the developer profile
  mySystem = {
    # Machine-specific settings (CUSTOMIZE THESE)
    hostname = "CHANGE-ME";  # Set your machine hostname

    # Machine-specific feature overrides
    features = {
      desktop = {
        enableRemoteDesktop = mkDefault false;  # Enable if needed for remote access
      };

      development = {
        # Customize development languages for this machine
        languages = [ "nodejs" "go" "python" "rust" "nix" ];
        # Add "java", "cpp" if needed
      };

      virtualization = {
        # Enable virtualization for development
        enableDocker = mkDefault true;
        enablePodman = mkDefault true;
        enableLibvirt = mkDefault true;
      };
    };

    # Machine-specific hardware settings (CUSTOMIZE THESE)
    hardware = {
      kernel = mkDefault "latest";  # Use latest kernel for development
      enableVirtualization = mkDefault true;
      enableRemoteDesktop = mkDefault false;
      gpu = mkDefault "none";  # Set to "intel", "amd", or "nvidia" based on hardware
    };
  };

  # Machine-specific Nix settings
  nix.settings = {
    cores = mkDefault 0;  # Use all available cores
    max-jobs = mkDefault "auto";
  };

  # Machine-specific packages (beyond profile defaults)
  environment.systemPackages = with pkgs; [
    # Add machine-specific packages here
    # Examples:
    # jetbrains.idea-ultimate
    # android-studio
    # blender
  ];

  # Machine-specific services
  services = {
    # Add machine-specific services here
    # Examples:
    # postgresql.enable = false;  # Use containers instead
  };

  # Machine-specific networking
  networking = {
    # Add machine-specific networking here
    # Examples:
    # firewall.allowedTCPPorts = [ 8080 ];
  };

  # Performance optimizations (customize based on hardware)
  boot = {
    # Add machine-specific boot parameters
    kernelParams = [
      # Examples:
      # "intel_pstate=active"  # For Intel CPUs
      # "amd_pstate=active"    # For AMD CPUs
    ];

    # Faster boot for development
    loader.timeout = mkDefault 3;
  };

  # Hardware-specific optimizations
  hardware = {
    # Enable based on actual hardware
    # cpu.intel.updateMicrocode = true;   # For Intel CPUs
    # cpu.amd.updateMicrocode = true;     # For AMD CPUs
  };

  # Machine-specific user configuration
  users.users.${config.mySystem.user} = {
    # Add machine-specific user packages
    packages = with pkgs; [
      # Examples:
      # slack
      # zoom-us
      # teams
    ];
  };
}

# CUSTOMIZATION CHECKLIST:
# [ ] Set hostname in mySystem.hostname
# [ ] Configure GPU type in mySystem.hardware.gpu
# [ ] Review development languages needed
# [ ] Add machine-specific packages
# [ ] Configure hardware-specific optimizations
# [ ] Test configuration with: nix flake check
