# Desktop Profile - Lightweight desktop for basic usage and thin clients
# Target: Low-spec machines, basic productivity, remote access

{ lib, ... }:

with lib;

{
  imports = [
    ./base.nix
    ../features/desktop.nix
  ];

  # Desktop profile configuration - feature enablement
  mySystem = {
    # Override hostname default for desktop systems
    hostname = mkDefault "desktop";

    # Enable desktop features
    features = {
      desktop = {
        enable = true;  # Main feature for this profile
        environment = mkDefault "plasma";
        displayManager = mkDefault "sddm";
        enableWayland = mkDefault true;
        enableX11 = mkDefault true;
        enableRemoteDesktop = mkDefault true;
      };

      # Desktop systems don't need development tools by default
      development = {
        enable = mkDefault false;
        languages = mkDefault [ "nix" ];
        editors = mkDefault [ "vim" ];
      };

      # Basic virtualization disabled for lightweight systems
      virtualization = {
        enable = mkDefault false;
      };

      # Server features disabled for desktop
      server = {
        enable = mkDefault false;
      };
    };

    # Desktop-optimized hardware settings
    hardware = {
      kernel = mkDefault "latest"; # Latest kernel for better hardware support
      enableVirtualization = mkDefault false;
      enableRemoteDesktop = mkDefault true;
      gpu = mkDefault "none"; # Auto-detect or set per machine
    };
  };

  # Desktop packages are provided by the desktop feature module

  # All desktop implementation is provided by the desktop feature module
}
