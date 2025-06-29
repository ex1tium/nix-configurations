# Developer Profile - Essential development tools and capabilities
# Target: Work laptops, daily driver machines, development workstations

{ lib, ... }:

with lib;

{
  imports = [
    # Inherit all desktop capabilities
    ./desktop.nix
    # Add development features
    ../features/development.nix
    # Add virtualization features
    ../features/virtualization.nix
  ];

  # Developer profile extends desktop with development capabilities
  mySystem = {
    # Override hostname default for developer systems
    hostname = mkDefault "developer";

    # Enable development features
    features = {
      # Keep desktop features enabled (inherited from desktop.nix)
      desktop = {
        enable = mkDefault true;
        environment = mkDefault "plasma"; # KDE Plasma 6 for full-featured experience
        enableRemoteDesktop = mkDefault true;
      };

      # Enable comprehensive development tools
      development = {
        enable = true;  # Main feature for this profile
        languages = [ "nodejs" "go" "python" "rust" "nix" ];
        editors = [ "vscode" "neovim" ];
      };

      # Enhanced virtualization for development
      virtualization = {
        enable = true;  # Enable for development
      };

      # Server features for local development
      server = {
        enable = mkDefault false;
      };

      # Enable BTRFS snapshots for development systems
      # Provides automatic system and home directory snapshots
      btrfsSnapshots = {
        enable = mkDefault false; # Enabled automatically by installer for BTRFS systems
        autoSnapshots = mkDefault true;
      };
    };

    # Developer-optimized hardware settings
    hardware = {
      kernel = mkDefault "latest"; # Latest kernel for development
      enableVirtualization = mkDefault true;
      enableRemoteDesktop = mkDefault true;
      gpu = mkDefault "none"; # Set per machine based on hardware
    };
  };

  # All development implementation is provided by the development feature module
}
