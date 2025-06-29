# Hardware Compatibility Module
# Automatically detects and configures vendor-specific hardware settings
# Handles CPU (KVM modules), GPU detection, and virtualization optimizations

{ config, lib, pkgs, ... }:

with lib;

let
  # CPU vendor detection using Nix's built-in hardware detection
  cpuVendor = 
    if builtins.match ".*AuthenticAMD.*" (builtins.readFile /proc/cpuinfo) != null then "amd"
    else if builtins.match ".*GenuineIntel.*" (builtins.readFile /proc/cpuinfo) != null then "intel"
    else "unknown";

  # GPU detection with VM-aware logic
  gpuVendor = 
    let
      # Check multiple GPU cards (for passthrough scenarios)
      checkGpuCard = cardNum: vendor:
        builtins.pathExists "/sys/class/drm/card${toString cardNum}/device/vendor" &&
        builtins.match ".*${vendor}.*" (builtins.readFile "/sys/class/drm/card${toString cardNum}/device/vendor") != null;
      
      # Check for GPU vendor IDs across multiple cards
      intelGpu = checkGpuCard 0 "0x8086" || checkGpuCard 1 "0x8086" || checkGpuCard 2 "0x8086";
      amdGpu = checkGpuCard 0 "0x1002" || checkGpuCard 1 "0x1002" || checkGpuCard 2 "0x1002";
      nvidiaGpu = checkGpuCard 0 "0x10de" || checkGpuCard 1 "0x10de" || checkGpuCard 2 "0x10de";
      
      # Check for loaded GPU kernel modules (works in VMs with passthrough)
      hasIntelModule = builtins.pathExists "/proc/modules" &&
                       builtins.match ".*(i915|xe).*" (builtins.readFile "/proc/modules") != null;
      hasAmdModule = builtins.pathExists "/proc/modules" &&
                     builtins.match ".*(amdgpu|radeon).*" (builtins.readFile "/proc/modules") != null;
      hasNvidiaModule = builtins.pathExists "/proc/modules" &&
                        builtins.match ".*nvidia.*" (builtins.readFile "/proc/modules") != null;
      
      # Check for virtual GPU indicators (QEMU/VMware virtual graphics)
      hasVirtioGpu = builtins.pathExists "/proc/modules" &&
                     builtins.match ".*virtio_gpu.*" (builtins.readFile "/proc/modules") != null;
      hasVmwareGpu = builtins.pathExists "/proc/modules" &&
                     builtins.match ".*vmwgfx.*" (builtins.readFile "/proc/modules") != null;
      
      # VM-specific GPU detection (for virtual displays)
      isVmGpu = hasVirtioGpu || hasVmwareGpu;
      
      # Priority: Physical GPU > Passthrough GPU > Virtual GPU > None
      detectedVendor = 
        if intelGpu || hasIntelModule then "intel"
        else if amdGpu || hasAmdModule then "amd"
        else if nvidiaGpu || hasNvidiaModule then "nvidia"
        else if isVmGpu && isVirtualized then "intel"  # Default to Intel for VM virtual graphics
        else "none";
    in
    detectedVendor;

  # Virtualization detection
  isVirtualized = 
    builtins.pathExists /proc/xen ||
    (builtins.pathExists /proc/cpuinfo && 
     builtins.match ".*hypervisor.*" (builtins.readFile /proc/cpuinfo) != null) ||
    (builtins.pathExists /sys/class/dmi/id/product_name &&
     builtins.match ".*(VMware|VirtualBox|QEMU).*" 
       (builtins.readFile /sys/class/dmi/id/product_name) != null);

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
    # Automatically set GPU type based on detection (if auto-detection is enabled)
    mySystem.hardware.gpu = mkIf config.mySystem.hardware.compatibility.autoDetectGpu (
      mkDefault (config.mySystem.hardware.compatibility.gpuVendorOverride or gpuVendor)
    );

    # Debug information (only shown during build if debug is enabled)
    warnings = optionals config.mySystem.hardware.compatibility.debug [
      "Hardware Compatibility Debug: CPU Vendor = ${cpuVendor}"
      "Hardware Compatibility Debug: GPU Vendor = ${gpuVendor}"
      "Hardware Compatibility Debug: Virtualized = ${toString isVirtualized}"
      "Hardware Compatibility Debug: KVM Modules = ${toString kvmModules}"
      "Hardware Compatibility Debug: Auto GPU Detection = ${toString config.mySystem.hardware.compatibility.autoDetectGpu}"
      "Hardware Compatibility Debug: Final GPU Config = ${config.mySystem.hardware.gpu}"
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
    boot.kernelParams = mkIf (config.mySystem.hardware.compatibility.autoVmOptimizations && isVirtualized) 
      vmKernelParams;

    # Additional VM optimizations
    boot.kernel.sysctl = mkIf isVirtualized {
      # VM-specific sysctl optimizations
      "vm.swappiness" = mkDefault 10;
      "vm.vfs_cache_pressure" = mkDefault 50;
    };

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
      CONFIGURED_GPU_TYPE=${config.mySystem.hardware.gpu}
      
      # This file is for informational purposes only
      # Configuration is applied automatically through NixOS modules
    '';
  };
}
