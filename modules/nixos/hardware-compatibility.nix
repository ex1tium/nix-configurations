# Enhanced Hardware Detection Module
# Production-ready: handles real hardware and complex VM/passthrough scenarios.
# Merges the best features of previous hardware detection modules.

{ config, lib, pkgs, ... }:

with lib;

let
  # Safe evaluation wrapper for file system access
  safeReadFile = path: default:
    if builtins.pathExists path
    then (builtins.tryEval (builtins.readFile path)).value or default
    else default;

  # Enhanced CPU vendor detection with robust fallback
  cpuVendor =
    let
      cpuinfo = safeReadFile "/proc/cpuinfo" "";
      vendorMatch = builtins.match ".*vendor_id[[:space:]]*:[[:space:]]*([^[:space:]]+).*" cpuinfo;
      vendorId = if vendorMatch != null then head vendorMatch else "";
    in
    if (builtins.match ".*GenuineIntel.*" vendorId) != null then "intel"
    else if (builtins.match ".*AuthenticAMD.*" vendorId) != null then "amd"
    else pkgs.stdenv.hostPlatform.parsed.cpu.name; # Fallback to Nix detection

  # Enhanced virtualization detection
  isVirtualized =
    let
      dmiProduct = safeReadFile "/sys/class/dmi/id/product_name" "";
      dmiVendor = safeReadFile "/sys/class/dmi/id/sys_vendor" "";
      cpuinfo = safeReadFile "/proc/cpuinfo" "";

      vmIndicators = [
        "QEMU"
        "VirtualBox"
        "VMware"
        "Microsoft Corporation" # Hyper-V
        "Xen"
        "KVM"
        "Standard PC"
        "Virtual Machine"
      ];

      hasVmIndicator = builtins.any (indicator:
        (builtins.match ".*${indicator}.*" dmiProduct) != null ||
        (builtins.match ".*${indicator}.*" dmiVendor) != null
      ) vmIndicators;

      hasHypervisorFlag = (builtins.match ".*hypervisor.*" cpuinfo) != null;

    in hasVmIndicator || hasHypervisorFlag;

  # Enhanced GPU detection with better VM/passthrough awareness
  gpuVendor =
    let
      # Check PCI devices for VGA controllers (class 0300)
      pciDevices = safeReadFile "/proc/bus/pci/devices" "";
      vgaControllers =
        if pciDevices != "" 
        then builtins.filter (line: (builtins.match ".*0300.*" line) != null)
             (builtins.split "\n" pciDevices)
        else [];

      # Extract vendor IDs from VGA controllers
      # Passthrough GPUs will appear here with their real vendor IDs
      hasNvidiaGpu = builtins.any (line: (builtins.match ".*10de.*" line) != null) vgaControllers;
      hasAmdGpu = builtins.any (line: (builtins.match ".*1002.*" line) != null) vgaControllers;
      hasIntelGpu = builtins.any (line: (builtins.match ".*8086.*" line) != null) vgaControllers;
      # Standard QEMU/Bochs VGA adapter
      hasQemuGpu = builtins.any (line: (builtins.match ".*1234.*" line) != null) vgaControllers;
      # VirtIO GPU
      hasVirtioGpu = builtins.any (line: (builtins.match ".*1af4.*" line) != null) vgaControllers;


      # Check for loaded kernel modules as a secondary detection method
      lsmodOutput = safeReadFile "/proc/modules" "";
      hasNvidiaModule = (builtins.match ".*nvidia.*" lsmodOutput) != null;
      hasAmdModule = (builtins.match ".*amdgpu.*" lsmodOutput) != null || (builtins.match ".*radeon.*" lsmodOutput) != null;
      hasIntelModule = (builtins.match ".*i915.*" lsmodOutput) != null || (builtins.match ".*xe.*" lsmodOutput) != null;

    in
    # Priority-based detection for multi-GPU or passthrough scenarios
    if hasNvidiaGpu || hasNvidiaModule then "nvidia"
    else if hasAmdGpu || hasAmdModule then "amd"
    else if hasIntelGpu || hasIntelModule then "intel"
    # Handle virtual GPUs specifically. If a physical GPU is passed through,
    # it should be detected above. This handles VMs without passthrough.
    else if isVirtualized && (hasQemuGpu || hasVirtioGpu) then "none"
    # Fallback for VMs where no specific GPU is detected
    else if isVirtualized then "none"
    # Fallback for physical systems, assuming Intel iGPU if nothing else is found
    else "intel";

  # Generate appropriate KVM modules based on detected CPU
  kvmModules =
    if cpuVendor == "intel" then [ "kvm-intel" ]
    else if cpuVendor == "amd" then [ "kvm-amd" ]
    else [];

  # VM optimization parameters
  vmKernelParams = optionals isVirtualized [
    "kvm.ignore_msrs=1"
    "kvm.report_ignored_msrs=0"
    "mitigations=off"
  ];

  # IOMMU parameters for virtualization/passthrough, based on CPU vendor
  iommuParams =
    if cpuVendor == "intel" then [ "intel_iommu=on" "iommu=pt" ]
    else if cpuVendor == "amd" then [ "amd_iommu=on" "iommu=pt" ]
    else [];

in

{
  options.mySystem.hardware = {
    enable = mkEnableOption "production-ready hardware compatibility detection and configuration";

    cpu.vendor = mkOption {
      type = types.enum ([ "intel" "amd" "unknown" ] ++ [ pkgs.stdenv.hostPlatform.parsed.cpu.name ]);
      default = cpuVendor;
      description = "Detected CPU vendor for hardware-specific optimizations.";
    };

    gpu = mkOption {
      type = types.enum [ "intel" "amd" "nvidia" "none" "auto" ];
      default = "auto"; # Default to auto-detection
      description = "GPU vendor for driver configuration. 'auto' uses the detected value.";
    };

    detectedGpu = mkOption {
      type = types.enum [ "intel" "amd" "nvidia" "none" ];
      readOnly = true;
      default = gpuVendor;
      description = "The GPU vendor automatically detected by the system.";
    };

    isVirtualized = mkOption {
      type = types.bool;
      default = isVirtualized;
      description = "Whether the system is detected as running in a virtual machine.";
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug output for hardware detection.";
    };
  };

  config = mkIf config.mySystem.hardware.enable {

    # Configure KVM modules based on detected CPU vendor
    boot.kernelModules = mkDefault kvmModules;

    # Add VM-specific and IOMMU kernel parameters
    boot.kernelParams = mkDefault (vmKernelParams ++ iommuParams);

    # System optimization based on virtualization status
    boot.kernel.sysctl = mkIf isVirtualized {
      "vm.swappiness" = mkDefault 10;
      "kernel.sched_migration_cost_ns" = mkDefault 5000000;
    };

    # Debug output
    warnings = optionals config.mySystem.hardware.debug [
      "Hardware Detection Debug: CPU Vendor = ${config.mySystem.hardware.cpu.vendor}"
      "Hardware Detection Debug: GPU Setting = ${config.mySystem.hardware.gpu}"
      "Hardware Detection Debug: Detected GPU = ${config.mySystem.hardware.detectedGpu}"
      "Hardware Detection Debug: Virtualized = ${toString config.mySystem.hardware.isVirtualized}"
      "Hardware Detection Debug: KVM Modules = ${toString kvmModules}"
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
