# Enhanced Hardware Detection Module
#
# Workflow:
# 1. The `install_machine.sh` script runs `nixos-facter --json` as root during installation.
# 2. The JSON output is saved to `machines/<machine-name>/facter.json`.
# 3. This module reads the static JSON file for pure, reproducible hardware detection.

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
    # Get the list of CPUs, default to an empty list
    cpus = getAttr "hardware.cpu" [];
    # Check if the list is not empty and get the vendor name from the first CPU
    vendorString = if cpus != [] then
                     (lib.elemAt cpus 0).vendor_name or ""
                   else
                     "";
  in
  if (builtins.match ".*Intel.*" vendorString) != null then "intel"
  else if (builtins.match ".*(AMD|Advanced Micro Devices).*" vendorString) != null then "amd"
  else "unknown");

  detectedIsVirtualized = (getAttr "virtualisation" "none") != "none";

  detectedGpuVendor = (let
    graphicsCards = getAttr "hardware.graphics_card" [];
    # Helper to check for a vendor by hex ID in the list of graphics cards.
    hasGpuById = vendorId: builtins.any (card: (card.vendor.hex or "") == vendorId) graphicsCards;
  in
  # Priority-based detection: NVIDIA > AMD > Intel
  if hasGpuById "10de" then "nvidia"
  else if hasGpuById "1002" then "amd"
  else if hasGpuById "8086" then "intel"
  # Use the top-level virtualization key as a reliable fallback for VMs.
  else if detectedIsVirtualized then "none"
  else "none"); # Default to none if no real GPU is found.

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

    gpu = {
      detection = mkOption {
        type = types.enum [ "auto" "intel" "amd" "nvidia" "none" ];
        default = "auto";
        description = "GPU vendor for driver configuration. 'auto' uses the detected value.";
      };

      detectedVendor = mkOption {
        type = types.enum [ "intel" "amd" "nvidia" "none" ];
        readOnly = true;
        default = detectedGpuVendor;
        description = "The GPU vendor automatically detected by the system.";
      };

      vendor = mkOption {
        type = types.enum [ "intel" "amd" "nvidia" "none" ];
        readOnly = true;
        default = if config.mySystem.hardware.gpu.detection == "auto"
                  then config.mySystem.hardware.gpu.detectedVendor
                  else config.mySystem.hardware.gpu.detection;
        description = "The final GPU vendor used for configuration.";
      };
    };

    virtualization = {
      isVm = mkOption {
        type = types.bool;
        default = detectedIsVirtualized;
        description = "Whether the system is detected as running in a virtual machine.";
      };
    };

    debug = mkOption {
      type = types.bool;
      default = true;
      description = "Enable debug output for hardware detection.";
    };
  };

  config = mkIf config.mySystem.hardware.enable (let
    cfg = config.mySystem.hardware;
    kvmModules = if cfg.cpu.vendor == "intel" then [ "kvm-intel" ]
                 else if cfg.cpu.vendor == "amd" then [ "kvm-amd" ]
                 else [];
    iommuParams = if cfg.cpu.vendor == "intel" then [ "intel_iommu=on" "iommu=pt" ]
                  else if cfg.cpu.vendor == "amd" then [ "amd_iommu=on" "iommu=pt" ]
                  else [];

    # Safely access virtualization feature options with defaults
    enableKvm = config.mySystem.features.virtualization.enableKvm or true;
    enableKvmNested = config.mySystem.features.virtualization.enableKvmNested or false;
    enableGpuPassthrough = config.mySystem.features.virtualization.enableGpuPassthrough or false;
  in {
    # Load KVM modules only on physical hosts or on VMs with nested virt enabled.
    boot.kernelModules = optionals (enableKvm && (!cfg.virtualization.isVm || enableKvmNested)) kvmModules;

    # Also add KVM modules to the initrd under the same conditions.
    boot.initrd.availableKernelModules = optionals (enableKvm && (!cfg.virtualization.isVm || enableKvmNested)) kvmModules;

    # Generate kernel parameters for IOMMU based on detected CPU
    boot.kernelParams = optionals enableGpuPassthrough iommuParams;

    # Add warnings for debugging
    warnings = optionals cfg.debug [
      "Hardware Detection Debug: CPU Vendor = ${cfg.cpu.vendor}"
      "Hardware Detection Debug: GPU Detection = ${cfg.gpu.detection}"
      "Hardware Detection Debug: Detected GPU Vendor = ${cfg.gpu.detectedVendor}"
      "Hardware Detection Debug: Final GPU Vendor = ${cfg.gpu.vendor}"
      "Hardware Detection Debug: Virtualized = ${toString cfg.virtualization.isVm}"
      "Hardware Detection Debug: KVM Modules = ${toString config.boot.kernelModules}"
    ];

    # System info for debugging
    system.build.hardware-info = pkgs.writeText "hardware-info" ''
t      Hardware Detection Results:
      ===================================
      CPU Vendor: ${cfg.cpu.vendor}
      GPU Detection: ${cfg.gpu.detection}
      Detected GPU Vendor: ${cfg.gpu.detectedVendor}
      Final GPU Vendor: ${cfg.gpu.vendor}
      Virtualized: ${toString cfg.virtualization.isVm}
      KVM Modules: ${toString kvmModules}
      IOMMU Params: ${toString iommuParams}
    '';
  });
}
