# Hardware Compatibility Configuration Example
# This shows how to use the hardware compatibility module in your machine configurations

{
  # Enable automatic hardware compatibility detection and fixes
  mySystem.hardware.compatibility = {
    enable = true;  # Enable the hardware compatibility module
    
    # Automatically detect and configure correct KVM modules (Intel vs AMD)
    autoDetectKvm = true;  # Default: true
    
    # Automatically detect and configure GPU drivers (Intel/AMD/NVIDIA)
    autoDetectGpu = true;  # Default: true
    
    # Apply VM-specific optimizations when virtualization is detected
    autoVmOptimizations = true;  # Default: true
    
    # Override CPU vendor detection if needed (usually not necessary)
    # cpuVendorOverride = "intel";  # or "amd"
    
    # Override GPU vendor detection if needed (usually not necessary)
    # gpuVendorOverride = "nvidia";  # or "intel", "amd", "none"
    
    # Enable debug logging during build (useful for troubleshooting)
    debug = false;  # Set to true to see detection results in build warnings
  };
}

# What this module does automatically:
#
# 1. CPU Vendor Detection:
#    - Reads /proc/cpuinfo to detect Intel vs AMD CPU
#    - Configures appropriate KVM modules (kvm-intel or kvm-amd)
#    - Blacklists incompatible KVM modules
#
# 2. GPU Vendor Detection:
#    - Checks /sys/class/drm/card0/device/vendor for GPU vendor IDs
#    - Detects Intel (0x8086), AMD (0x1002), NVIDIA (0x10de) GPUs
#    - Falls back to checking loaded kernel modules (i915, amdgpu, nvidia)
#    - Automatically sets mySystem.hardware.gpu configuration
#
# 3. Virtualization Detection:
#    - Detects QEMU/KVM, VMware, VirtualBox, Xen environments
#    - Applies VM-specific kernel parameters for better compatibility
#    - Enables QEMU guest agent and other VM optimizations
#
# 4. Automatic Fixes:
#    - Prevents the "kvm_amd: CPU isn't AMD" boot error
#    - Adds kernel parameters: kvm.ignore_msrs=1, kvm.report_ignored_msrs=0
#    - Optimizes sysctl settings for virtualized environments
#    - Automatically configures GPU drivers based on detected hardware
#
# 5. Debug Information:
#    - Creates /etc/hardware-compatibility-info with detection results
#    - Shows CPU vendor, GPU vendor, virtualization status
#    - Optional build-time warnings showing detected hardware
#
# This replaces the need for:
# - Manual GPU configuration in machine configs
# - Shell script patching of hardware-configuration.nix
# - Guessing hardware types for driver configuration
# 
# Provides a clean, declarative, and fully automated solution.
