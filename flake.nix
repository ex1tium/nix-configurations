{
  description = "Multi-machine NixOS configuration with Home Manager, devShells, and sops-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, sops-nix, ... }: {
    nixosConfigurations = {
      elara = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./machines/elara/configuration.nix
          ./modules/features/secrets.nix
        ];
      };
    };

    homeConfigurations = {
      elaraUser = home-manager.lib.homeManagerConfiguration {
        inherit nixpkgs;
        modules = [
          ./modules/home/common-home.nix
        ];
      };
    };

    devShells = {
      rust = import ./modules/devshells/rust.nix { pkgs = nixpkgs; };
      go = import ./modules/devshells/go.nix { pkgs = nixpkgs; };
    };
  };
}
