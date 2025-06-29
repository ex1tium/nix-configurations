# Comprehensive Validation Module
# Provides robust error handling, validation, and warnings for the entire NixOS configuration
# This module ensures configuration consistency and prevents common misconfigurations

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mySystem;
  
  # Helper functions for validation
  isLowSpecHardware = cfg.features.desktop.lowSpec or false;
  hasDesktop = cfg.features.desktop.enable;
  hasDevelopment = cfg.features.development.enable;
  hasVirtualization = cfg.features.virtualization.enable;
  hasServer = cfg.features.server.enable;
  
  # Hardware detection helpers
  gpuType = cfg.hardware.gpu;
  kernelVersion = cfg.hardware.kernel;
  hasVirtualizationHardware = cfg.hardware.enableVirtualization;
  
  # Resource requirement calculations
  minRamForDesktop = 2048; # MB
  minRamForDevelopment = 4096; # MB
  minRamForVirtualization = 8192; # MB
  
  # Feature compatibility matrix
  incompatibleFeatures = [
    { features = [ "virtualization.enableVirtualbox" "virtualization.enableLibvirt" ]; 
      reason = "VirtualBox and libvirt/KVM cannot run simultaneously"; }
    { features = [ "desktop.lowSpec" "features.virtualization.enable" ]; 
      reason = "Virtualization is not recommended on low-spec hardware"; }
  ];
  
  # Performance validation helpers
  hasPerformanceIssues = 
    (isLowSpecHardware && hasVirtualization) ||
    (gpuType == "none" && hasDesktop && cfg.features.desktop.environment == "plasma") ||
    (kernelVersion == "latest" && !hasDevelopment);

in
{
  config = {
    # Comprehensive Assertions - Critical configuration validation
    assertions = [
      # Basic system configuration validation
      {
        assertion = cfg.user != "";
        message = "mySystem.user must be set to a non-empty string. Please specify the primary user account.";
      }
      {
        assertion = cfg.hostname != "";
        message = "mySystem.hostname must be set to a non-empty string. Please specify a valid hostname.";
      }
      {
        assertion = stringLength cfg.hostname <= 63;
        message = "mySystem.hostname '${cfg.hostname}' is too long (max 63 characters). Please use a shorter hostname.";
      }
      {
        assertion = !(builtins.match ".*[[:space:]].*" cfg.hostname != null);
        message = "mySystem.hostname '${cfg.hostname}' cannot contain spaces. Please use a valid hostname format.";
      }
      
      # Desktop environment validation
      {
        assertion = hasDesktop -> (cfg.features.desktop.environment != "");
        message = "Desktop environment must be specified when desktop features are enabled. Set mySystem.features.desktop.environment to 'plasma' or 'xfce'.";
      }
      {
        assertion = hasDesktop -> (cfg.features.desktop.enableWayland || cfg.features.desktop.enableX11);
        message = "At least one display server (Wayland or X11) must be enabled when desktop features are active.";
      }
      {
        assertion = !(cfg.features.desktop.environment == "xfce" && cfg.features.desktop.enableWayland && !cfg.features.desktop.enableX11);
        message = "XFCE requires X11 support. Wayland-only configuration is not supported for XFCE.";
      }
      
      # Virtualization compatibility validation
      {
        assertion = !(cfg.features.virtualization.enableVirtualbox && cfg.features.virtualization.enableLibvirt);
        message = "VirtualBox and libvirt/KVM cannot be enabled simultaneously due to kernel module conflicts. Choose one virtualization platform.";
      }
      {
        assertion = hasVirtualization -> hasVirtualizationHardware;
        message = "Virtualization features are enabled but hardware virtualization is disabled. Set mySystem.hardware.enableVirtualization = true.";
      }
      {
        assertion = !(cfg.features.virtualization.enableDocker && cfg.features.virtualization.enablePodman);
        message = "Docker and Podman should not be enabled simultaneously as they may conflict. Choose one container runtime.";
      }
      
      # Development environment validation
      {
        assertion = hasDevelopment -> (cfg.features.development.languages != []);
        message = "Development features are enabled but no programming languages are specified. Please add languages to mySystem.features.development.languages.";
      }
      {
        assertion = hasDevelopment -> (cfg.features.development.editors != []);
        message = "Development features are enabled but no editors are specified. Please add editors to mySystem.features.development.editors.";
      }
      
      # Hardware compatibility validation
      {
        assertion = !(gpuType == "nvidia" && cfg.features.desktop.enableWayland && !cfg.features.desktop.enableX11);
        message = "NVIDIA GPUs may have issues with Wayland-only configurations. Consider enabling X11 as fallback.";
      }
      {
        assertion = !(isLowSpecHardware && cfg.features.desktop.environment == "plasma");
        message = "KDE Plasma is not recommended for low-spec hardware. Consider using XFCE instead by setting mySystem.features.desktop.environment = 'xfce'.";
      }
      
      # Security validation
      {
        assertion = !(cfg.features.desktop.enableRemoteDesktop && !hasServer && !cfg.features.development.enable);
        message = "Remote desktop is enabled on a non-server, non-development system. This may pose security risks.";
      }
      
      # Resource validation (basic checks)
      {
        assertion = !(isLowSpecHardware && hasVirtualization);
        message = "Virtualization features are not recommended on low-spec hardware as they require significant system resources.";
      }
    ];

    # Comprehensive Warnings - Non-critical but important recommendations
    warnings = []
      # Performance warnings
      ++ optional (isLowSpecHardware && hasDesktop && cfg.features.desktop.environment == "plasma")
         "KDE Plasma on low-spec hardware may be slow. Consider switching to XFCE for better performance."
      ++ optional (gpuType == "none" && hasDesktop)
         "No GPU acceleration configured. Desktop performance may be limited."
      ++ optional (kernelVersion == "latest" && !hasDevelopment && !hasServer)
         "Latest kernel selected for non-development system. Consider using 'stable' kernel for better stability."
      ++ optional (hasVirtualization && !hasDevelopment)
         "Virtualization is enabled but development features are disabled. Consider if virtualization is needed."
      
      # Development warnings
      ++ optional (hasDevelopment && !hasVirtualization)
         "Development features enabled without virtualization. Consider enabling containers for isolated development environments."
      ++ optional (hasDevelopment && !(cfg.features.virtualization.enableDocker || cfg.features.virtualization.enablePodman))
         "Development features enabled but no container runtime configured. Modern development often requires containers."
      ++ optional (hasDevelopment && cfg.features.development.languages == [ "nix" ])
         "Only Nix language support enabled for development. Consider adding other languages if needed."
      
      # Desktop warnings
      ++ optional (hasDesktop && cfg.features.desktop.environment == "xfce" && cfg.features.desktop.enableWayland)
         "XFCE with Wayland is experimental and may have stability issues. X11 is recommended for XFCE."
      ++ optional (hasDesktop && cfg.features.desktop.environment == "plasma" && !cfg.features.desktop.enableWayland)
         "KDE Plasma works best with Wayland enabled for modern features and better performance."
      ++ optional (hasDesktop && !cfg.features.desktop.enableRemoteDesktop && hasDevelopment)
         "Remote desktop is disabled on development system. Consider enabling for remote development access."
      
      # Security warnings (refined for development VMs)
      ++ optional (cfg.features.desktop.enableRemoteDesktop && !hasServer && !hasDevelopment)
         "Remote desktop enabled on non-server, non-development system. Ensure proper firewall configuration and strong authentication."
      ++ optional (hasDevelopment && !hasServer && !cfg.features.desktop.enableRemoteDesktop)
         "Development features enabled without server hardening. Consider enabling server features for additional security or remote desktop for development access."
      
      # Hardware warnings
      ++ optional (gpuType == "nvidia" && cfg.features.desktop.enableWayland)
         "NVIDIA with Wayland may have compatibility issues. Monitor for graphics problems."
      ++ optional (hasVirtualizationHardware && !hasVirtualization && hasDevelopment)
         "Hardware virtualization available but not enabled. Consider enabling for development containers."
      
      # Configuration consistency warnings
      ++ optional (hasServer && hasDesktop)
         "Both server and desktop features enabled. This is unusual - verify this is intentional."
      ++ optional (cfg.features.desktop.lowSpec && cfg.features.development.enable)
         "Low-spec hardware with development features may have performance issues during builds."
      
      # Resource warnings
      ++ optional hasPerformanceIssues
         "Current configuration may have performance issues. Review hardware requirements and feature selection.";
  };
}
