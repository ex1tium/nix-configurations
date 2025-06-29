# Enhanced Hardware Detection Module
# Production-ready: handles real hardware and complex VM/passthrough scenarios.
# Merges the best features of previous hardware detection modules.

{ config, lib, pkgs, ... }:

with lib;

let
  # Attempt to read and parse the facter.json file provided via NixOS options.
  # This makes hardware detection pure, as it relies on a static data source.
  facterData =
    let
      facterFile = config.mySystem.hardware.facterFile;
    in
    if facterFile != null && builtins.pathExists facterFile then
      builtins.fromJSON (builtins.readFile facterFile)
    else
      {}; # Return an empty set if the file is not specified or doesn't exist.

  # Helper to safely access nested attributes from the parsed facter data.
  getAttr = path: default: lib.attrByPath (lib.splitString "." path) default facterData;

  # --- Hardware detection logic based on facter data ---

  detectedCpuVendor = (let
    # Example path: hardware.cpu.0.vendor = "GenuineIntel"
    vendorString = getAttr "hardware.cpu.0.vendor" "";
  in
  if (builtins.match ".*Intel.*" vendorString) != null then "intel"
  else if (builtins.match ".*(AMD|Advanced Micro Devices).*" vendorString) != null then "amd"
  else "unknown");

  detectedIsVirtualized = (getAttr "virtualisation" "none") != "none";

  detectedGpuVendor = (let
    graphicsCards = getAttr "hardware.graphics_card" [];
    # Helper to check for a vendor by name in the list of graphics cards.
    hasGpu = vendorName: builtins.any (card: (builtins.match ".*${vendorName}.*" (card.vendor or ""))) graphicsCards;
  in
  # Priority-based detection: NVIDIA > AMD > Intel > Virtual
  if hasGpu "NVIDIA" then "nvidia"
  else if hasGpu "(AMD|Advanced Micro Devices)" then "amd"
  else if hasGpu "Intel" then "intel"
  # Use the top-level virtualization key as a reliable fallback for VMs.
  else if detectedIsVirtualized then "none"
  else "none"); # Default to none if no GPU is found.

in

{
  options.mySystem.hardware = {
    enable = mkEnableOption "production-ready hardware compatibility detection and configuration";

    facterFile = mkOption {
      type = with types; nullOr path;
      default = null;
      description = "Path to the facter.json file for hardware detection.";
    };

    cpu.vendor = mkOption {
      type = types.enum [ "intel" "amd" "unknown" ];
      default = detectedCpuVendor;
      description = "Detected CPU vendor for hardware-specific optimizations.";
    };

    gpu = mkOption {
      type = types.enum [ "intel" "amd" "nvidia" "none" "auto" ];
      default = "auto";
      description = "GPU vendor for driver configuration. 'auto' uses the detected value.";
    };

    detectedGpu = mkOption {
      type = types.enum [ "intel" "amd" "nvidia" "none" ];
      readOnly = true;
      default = if config.mySystem.hardware.gpu == "auto" then detectedGpuVendor else config.mySystem.hardware.gpu;
      description = "The GPU vendor automatically detected by the system.";
    };

    isVirtualized = mkOption {
      type = types.bool;
      default = detectedIsVirtualized;
      description = "Whether the system is detected as running in a virtual machine.";
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug output for hardware detection.";
    };
  };

  config = mkIf config.mySystem.hardware.enable {
    # Generate appropriate KVM modules based on detected CPU
    boot.kernelModules = let
      kvmVendor = if config.mySystem.hardware.cpu.vendor == "intel" then [ "kvm-intel" ]
                  else if config.mySystem.hardware.cpu.vendor == "amd" then [ "kvm-amd" ]
                  else [];
    in
      optionals config.virtualisation.enableKvm kvmVendor;

    # Generate kernel parameters for IOMMU based on detected CPU
    boot.kernelParams = let
      iommuParams = if config.mySystem.hardware.cpu.vendor == "intel" then [ "intel_iommu=on" "iommu=pt" ]
                    else if config.mySystem.hardware.cpu.vendor == "amd" then [ "amd_iommu=on" "iommu=pt" ]
                    else [];
    in
      optionals config.virtualisation.enableGpuPassthrough iommuParams;

    # Add warnings for debugging
    warnings = optionals config.mySystem.hardware.debug [
      "Hardware Detection Debug: CPU Vendor = ${config.mySystem.hardware.cpu.vendor}"
      "Hardware Detection Debug: GPU Setting = ${config.mySystem.hardware.gpu}"
      "Hardware Detection Debug: Detected GPU = ${config.mySystem.hardware.detectedGpu}"
      "Hardware Detection Debug: Virtualized = ${toString config.mySystem.hardware.isVirtualized}"
      "Hardware Detection Debug: KVM Modules = ${toString config.boot.kernelModules}"
    ];

    # System info for debugging
    system.build.hardware-info = pkgs.writeText "hardware-info" ''
      Hardware Detection Results:
      ===================================
      CPU Vendor: ${config.mySystem.hardware.cpu.vendor}
      GPU Setting: ${config.mySystem.hardware.gpu}
      Detected GPU: ${config.mySystem.hardware.detectedGpu}
      Virtualized: ${toString config.mySystem.hardware.isVirtualized}
      KVM Modules: ${toString kvmModules}
      VM Kernel Params: ${toString vmKernelParams}
      IOMMU Params: ${toString iommuParams}
    '';
  };
}
