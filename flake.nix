# Main entry point for the NixOS configuration
# This flake.nix defines the entire system configuration structure

{
  # Brief description of what this flake provides
  description = "Multi-machine NixOS configuration with Home Manager, devShells, and sops-nix";

  # External dependencies required by this flake
  inputs = {
    # The main nixpkgs repository containing all the packages
    nixpkgs.url = "github:NixOS/nixpkgs";

    # Home Manager for managing user-specific configurations
    home-manager = {
      url = "github:nix-community/home-manager";
      # Use the same nixpkgs as the main system
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sops-nix for managing secrets (passwords, keys, etc.)
    sops-nix = {
      url = "github:Mic92/sops-nix";
      # Use the same nixpkgs as the main system
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Function that produces the flake's outputs based on its inputs
  outputs = { nixpkgs, home-manager, sops-nix, ... }: {
    # NixOS system configurations
    # Each entry here represents a complete system configuration
    nixosConfigurations = {
      # Configuration for the machine named "elara"
      elara = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";  # System architecture
        modules = [
          # Main configuration file for elara
          ./machines/elara/configuration.nix
          # Secrets management configuration
          ./modules/features/secrets.nix
        ];
      };
    };

    # Home Manager configurations for user environments
    homeConfigurations = {
      # Configuration for elaraUser
      elaraUser = home-manager.lib.homeManagerConfiguration {
        inherit nixpkgs;  # Use the same nixpkgs as above
        modules = [
          # Common home configuration shared across users
          ./modules/home/common-home.nix
        ];
      };
    };

    # Development shells for different programming environments
    devShells = {
      # Rust development environment
      rust = import ./modules/devshells/rust.nix { pkgs = nixpkgs; };
      # Go development environment
      go = import ./modules/devshells/go.nix { pkgs = nixpkgs; };
    };
  };
}
