# GPU Driver Configuration Module
# Automatically configures GPU drivers based on hardware.gpu setting

{ config, lib, pkgs, ... }:

with lib;

let
  # Use the new, more reliable hardware detection module.
  # The `gpuType` is determined by the user's setting (`config.mySystem.hardware.gpu`).
  # If it's set to 'auto', we use the automatically detected GPU vendor.
  detectedGpu = config.mySystem.hardware.detectedGpu;
  gpuType = if config.mySystem.hardware.gpu == "auto" then detectedGpu else config.mySystem.hardware.gpu;
  isDesktop = config.mySystem.features.desktop.enable;
in
{
  config = mkMerge [
    # Intel GPU Configuration
    (mkIf (gpuType == "intel") {
      # Intel graphics drivers
      hardware.graphics = {
        enable = true;
        enable32Bit = mkDefault true;
        extraPackages = with pkgs; [
          intel-media-driver    # VAAPI driver for newer Intel GPUs (>= Broadwell)
          intel-vaapi-driver    # VAAPI driver for older Intel GPUs
          vaapiIntel           # Legacy VAAPI driver
          vaapiVdpau           # VDPAU support
          libvdpau-va-gl       # VDPAU to VA-API bridge
          intel-compute-runtime # OpenCL support
          level-zero           # Level Zero API support
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          intel-vaapi-driver
          vaapiIntel
        ];
      };

      # Intel-specific kernel modules
      boot.kernelModules = [ "i915" ];
      
      # Intel GPU kernel parameters
      boot.kernelParams = [
        "i915.enable_guc=2"          # Enable GuC and HuC firmware loading
        "i915.enable_fbc=1"          # Enable framebuffer compression
        "i915.enable_psr=1"          # Enable panel self refresh
        "i915.fastboot=1"            # Enable fastboot
      ];

      # Intel GPU environment variables
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";   # Use iHD driver for newer Intel GPUs
        VDPAU_DRIVER = "va_gl";      # Use VA-GL for VDPAU
      };

      # Intel GPU packages
      environment.systemPackages = with pkgs; [
        intel-gpu-tools              # Intel GPU debugging tools
        libva-utils                  # VA-API utilities
        vdpauinfo                    # VDPAU info tool
      ] ++ optionals isDesktop [
        intel-media-sdk              # Intel Media SDK
      ];
    })

    # AMD GPU Configuration
    (mkIf (gpuType == "amd") {
      # AMD graphics drivers
      hardware.graphics = {
        enable = true;
        enable32Bit = mkDefault true;
        extraPackages = with pkgs; [
          amdvlk                     # AMD Vulkan driver
          mesa                       # Mesa drivers including radeonsi
          rocm-opencl-icd           # OpenCL support
          rocm-opencl-runtime       # OpenCL runtime
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          amdvlk
        ];
      };

      # AMD-specific kernel modules
      boot.kernelModules = [ "amdgpu" ];
      
      # AMD GPU kernel parameters
      boot.kernelParams = [
        "amdgpu.si_support=1"        # Enable Southern Islands support
        "amdgpu.cik_support=1"       # Enable Sea Islands support
        "radeon.si_support=0"        # Disable radeon driver for SI
        "radeon.cik_support=0"       # Disable radeon driver for CIK
      ];

      # AMD GPU environment variables
      environment.sessionVariables = {
        AMD_VULKAN_ICD = "RADV";     # Use RADV Vulkan driver
        LIBVA_DRIVER_NAME = "radeonsi";
        VDPAU_DRIVER = "radeonsi";
      };

      # AMD GPU packages
      environment.systemPackages = with pkgs; [
        radeontop                    # AMD GPU monitoring
        libva-utils                  # VA-API utilities
        vdpauinfo                    # VDPAU info tool
        vulkan-tools                 # Vulkan utilities
        clinfo                       # OpenCL info
      ] ++ optionals isDesktop [
        rocm-smi                     # ROCm system management
      ];
    })

    # NVIDIA GPU Configuration
    (mkIf (gpuType == "nvidia") {
      # NVIDIA proprietary drivers
      services.xserver.videoDrivers = [ "nvidia" ];
      
      hardware.nvidia = {
        # Use the NVidia open source kernel module (not to be confused with the
        # independent third-party "nouveau" open source driver).
        # Support is limited to the RTX 30 and newer series.
        # Full list of supported GPUs is at:
        # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
        # Only available from driver 515.43.04+
        # Currently alpha-quality/buggy, so false is currently the recommended setting.
        open = mkDefault false;  # Set to true for RTX 30 series and newer

        # Enable the Nvidia settings menu, accessible via `nvidia-settings`.
        nvidiaSettings = mkDefault true;

        # Optionally, you may need to select the appropriate driver version
        package = config.boot.kernelPackages.nvidiaPackages.stable;

        # Enable power management (experimental)
        powerManagement = {
          enable = mkDefault false;
          finegrained = mkDefault false;
        };
      };

      # NVIDIA graphics configuration
      hardware.graphics = {
        enable = true;
        enable32Bit = mkDefault true;
        extraPackages = with pkgs; [
          nvidia-vaapi-driver        # VAAPI support for NVIDIA
        ];
      };

      # NVIDIA-specific kernel parameters
      boot.kernelParams = [
        "nvidia-drm.modeset=1"       # Enable DRM kernel mode setting
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"  # Suspend support
      ];

      # NVIDIA environment variables
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        WLR_NO_HARDWARE_CURSORS = "1";  # Fix cursor issues in Wayland
      };

      # NVIDIA packages
      environment.systemPackages = with pkgs; [
        nvidia-system-monitor-qt     # NVIDIA system monitor
        libva-utils                  # VA-API utilities
        vulkan-tools                 # Vulkan utilities
        nvtop                        # NVIDIA GPU monitoring
      ] ++ optionals isDesktop [
        nvidia-settings              # NVIDIA control panel
      ];

      # Blacklist nouveau driver
      boot.blacklistedKernelModules = [ "nouveau" ];
    })

    # "none" GPU Configuration - for VMs without GPU passthrough or headless systems
    (mkIf (gpuType == "none") {
      # Minimal graphics support for headless/VM environments
      hardware.graphics = {
        enable = mkForce false;   # Force disable hardware graphics acceleration
        enable32Bit = mkForce false;  # Force disable 32-bit support (overrides common.nix)
      };
      
      # Ensure no GPU-specific kernel modules are loaded
      boot.blacklistedKernelModules = [
        "i915" "xe"          # Intel GPU modules
        "amdgpu" "radeon"    # AMD GPU modules  
        "nvidia" "nouveau"   # NVIDIA GPU modules
        "snd_hda_intel"      # Intel HDA audio (often tied to iGPU)
      ];
      
      # VM-friendly minimal package set
      environment.systemPackages = with pkgs; [
        # Basic OpenGL info tools only
        mesa-demos
      ];
    })

    # Common GPU configuration for all types
    (mkIf (gpuType != "none") {
      # Enable hardware acceleration
      hardware.graphics.enable = true;
      
      # GPU support packages (minimal essential set)
      environment.systemPackages = with pkgs; [
        # Vulkan support
        vulkan-loader
        vulkan-validation-layers
        vulkan-tools
        # OpenGL information and debugging
        glxinfo
        mesa-demos
      ] ++ optionals isDesktop [
        gpu-viewer                   # GPU information viewer (desktop only)
      ];

      # OpenGL and Vulkan environment variables
      environment.sessionVariables = {
        # Force hardware acceleration
        MESA_LOADER_DRIVER_OVERRIDE = mkIf (gpuType == "amd") "radeonsi";

        # Vulkan ICD selection
        VK_ICD_FILENAMES = mkIf (gpuType == "intel")
          "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      };
    })

    # Desktop-specific GPU configuration
    (mkIf (isDesktop && gpuType != "none") {
      # Hardware video acceleration
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      # Video acceleration packages
      environment.systemPackages = with pkgs; [
        libva-utils                  # VA-API utilities
        vdpauinfo                    # VDPAU information
        ffmpeg-full                  # FFmpeg with hardware acceleration
      ];

      # Gaming-related packages (optional)
      programs.gamemode.enable = mkDefault true;
      
      # Steam hardware acceleration
      programs.steam = mkIf (config.programs.steam.enable or false) {
        gamescopeSession.enable = mkDefault true;
      };
    })
  ];
}
