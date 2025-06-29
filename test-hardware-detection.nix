# Test Hardware Detection Script
# This configuration enables debug mode to test hardware compatibility detection
# Use this to validate detection works correctly in your environment

{ config, lib, pkgs, ... }:

{
  imports = [
    ./modules/nixos
  ];

  # Enable hardware compatibility with debug mode
  mySystem.hardware.compatibility = {
    enable = true;
    autoDetectKvm = true;
    autoDetectGpu = true;
    autoVmOptimizations = true;
    debug = true;  # This will show detection results as build warnings
  };

  # Minimal system configuration for testing
  mySystem = {
    hostname = "hardware-test";
    features = {
      desktop.enable = false;
      development.enable = false;
    };
  };

  # Test packages to verify detection
  environment.systemPackages = with pkgs; [
    pciutils  # For lspci command
    dmidecode # For hardware info
    systemd   # For systemd-detect-virt
  ];

  # This configuration will:
  # 1. Show detected CPU vendor in build warnings
  # 2. Show detected GPU vendor in build warnings  
  # 3. Show virtualization status
  # 4. Create /etc/hardware-compatibility-info with detection results
  # 5. Configure appropriate KVM modules and GPU drivers
}
