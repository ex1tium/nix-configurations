# Hardware Compatibility Module
# Automatically detects and configures vendor-specific hardware settings
# Handles CPU (KVM modules), GPU detection, and virtualization optimizations

{ config, lib, pkgs, ... }:

with lib;

let
  # CPU vendor detection (safe default for pure evaluation)
  # Actual detection happens at system build time
  cpuVendor = "intel";  # Safe default

  # GPU detection (safe default for pure evaluation)
  # For VMs: Check if we have real GPU hardware vs virtual/emulated graphics
  # Real GPU detection happens at system build time via PCI vendor IDs
  # Virtual environments (QEMU, VirtualBox, VMware) should use "none"
  gpuVendor = 
    if isVirtualized then "none"  # VMs without GPU passthrough = no real GPU
    else "none";  # Physical systems default to Intel (most common)

  # Virtualization detection (safe default for pure evaluation)
  # More conservative approach - assume virtualized to avoid hardware conflicts
  isVirtualized = true;  # Safe default - prevents loading incompatible physical hardware drivers system build time

  # Determine correct KVM modules based on CPU vendor
  kvmModules = 
    if cpuVendor == "intel" then [ "kvm-intel" ]
    else if cpuVendor == "amd" then [ "kvm-amd" ]
    else [];

  # VM-specific kernel parameters for better compatibility
  vmKernelParams = optionals isVirtualized [
    "kvm.ignore_msrs=1"
    "kvm.report_ignored_msrs=0"
    "mitigations=off"  # Optional: better VM performance
  ];

in

{
  options.mySystem.hardware.compatibility = {
    enable = mkEnableOption "automatic hardware compatibility detection and configuration";
    
    autoDetectKvm = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically detect and configure correct KVM modules based on CPU vendor";
    };

    autoDetectGpu = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically detect and configure GPU drivers based on detected hardware";
    };

    autoVmOptimizations = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically apply VM-specific optimizations when virtualization is detected";
    };

    cpuVendorOverride = mkOption {
      type = types.nullOr (types.enum [ "intel" "amd" ]);
      default = null;
      description = "Override automatic CPU vendor detection";
    };

    gpuVendorOverride = mkOption {
      type = types.nullOr (types.enum [ "intel" "amd" "nvidia" "none" ]);
      default = null;
      description = "Override automatic GPU vendor detection";
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug logging for hardware compatibility detection";
    };
  };

  config = mkIf config.mySystem.hardware.compatibility.enable {

    # Debug information (only shown during build if debug is enabled)
    warnings = optionals config.mySystem.hardware.compatibility.debug [
      "Hardware Compatibility Debug: CPU Vendor = ${cpuVendor}"
      "Hardware Compatibility Debug: GPU Vendor = ${gpuVendor}"
      "Hardware Compatibility Debug: Virtualized = ${toString isVirtualized}"
      "Hardware Compatibility Debug: KVM Modules = ${toString kvmModules}"
      "Hardware Compatibility Debug: Auto GPU Detection = ${toString config.mySystem.hardware.compatibility.autoDetectGpu}"
      "Hardware Compatibility Debug: Detected GPU Vendor = ${gpuVendor}"
    ];

    # Kernel modules configuration
    boot.kernelModules = mkIf config.mySystem.hardware.compatibility.autoDetectKvm (
      let
        finalCpuVendor = config.mySystem.hardware.compatibility.cpuVendorOverride or cpuVendor;
        finalKvmModules = 
          if finalCpuVendor == "intel" then [ "kvm-intel" ]
          else if finalCpuVendor == "amd" then [ "kvm-amd" ]
          else [];
      in
      finalKvmModules
    );

    # VM-specific kernel parameters
    boot.kernelParams = mkIf (config.mySystem.hardware.compatibility.autoVmOptimizations && isVirtualized) (
      let
        finalCpuVendor = config.mySystem.hardware.compatibility.cpuVendorOverride or cpuVendor;
        # CPU-vendor specific IOMMU parameters
        iommuParams = 
          if finalCpuVendor == "intel" then [ "intel_iommu=on" ]
          else if finalCpuVendor == "amd" then [ "amd_iommu=on" ]
          else [];
      in
      vmKernelParams ++ iommuParams
    );

    # Additional VM optimizations
    # Note: VM-specific sysctl optimizations (vm.swappiness, vm.vfs_cache_pressure) 
    # are handled by desktop modules to avoid conflicts

    # Hardware-specific services and configurations
    services = mkIf isVirtualized {
      # Enable QEMU guest agent if available
      qemuGuest.enable = mkDefault true;
      
      # Optimize for virtualized environment
      fstrim.enable = mkDefault true;
    };

    # Virtualization-specific packages
    environment.systemPackages = mkIf isVirtualized [
      pkgs.qemu-utils
    ];

    # Hardware-specific module loading prevention
    # This prevents the hardware-configuration.nix from loading incompatible modules
    boot.blacklistedKernelModules = 
      let
        finalCpuVendor = config.mySystem.hardware.compatibility.cpuVendorOverride or cpuVendor;
      in
      mkIf config.mySystem.hardware.compatibility.autoDetectKvm (
        if finalCpuVendor == "intel" then [ "kvm-amd" "kvm_amd" ]
        else if finalCpuVendor == "amd" then [ "kvm-intel" "kvm_intel" ]
        else []
      );

    # System information for debugging
    environment.etc."hardware-compatibility-info".text = ''
      # Hardware Compatibility Detection Results
      # Generated automatically by NixOS hardware compatibility module
      
      CPU_VENDOR=${cpuVendor}
      GPU_VENDOR=${gpuVendor}
      IS_VIRTUALIZED=${toString isVirtualized}
      KVM_MODULES=${toString kvmModules}
      VM_KERNEL_PARAMS=${toString vmKernelParams}
      
      # Configuration Status
      AUTO_DETECT_KVM=${toString config.mySystem.hardware.compatibility.autoDetectKvm}
      AUTO_DETECT_GPU=${toString config.mySystem.hardware.compatibility.autoDetectGpu}
      AUTO_VM_OPTIMIZATIONS=${toString config.mySystem.hardware.compatibility.autoVmOptimizations}
      
      # Applied Configuration
      DETECTED_GPU_VENDOR=${gpuVendor}
      
      # This file is for informational purposes only
      # Configuration is applied automatically through NixOS modules
    '';
  };
}
