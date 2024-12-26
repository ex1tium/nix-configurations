{
  description = "Multi-machine NixOS configuration with Home Manager, devShells, and sops-nix (PGP).";

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

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: builtins.listToAttrs (map (system: { name = system; value = f system; }) systems);
    in
    {
      # ----------------------------------------------------------------------------
      # 1. NixOS configurations
      # ----------------------------------------------------------------------------
      nixosConfigurations = forAllSystems (system: let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in {
        # Example machine "Elara"
        elara = lib.nixosSystem {
          inherit system;
          modules = [
            ./machines/elara/configuration.nix
            # hardware-configuration.nix is imported from configuration.nix
          ];
        };
      });

      # ----------------------------------------------------------------------------
      # 2. Home Manager configurations
      # ----------------------------------------------------------------------------
      homeConfigurations = forAllSystems (system: let
        pkgs = import nixpkgs { inherit system; };
      in {
        # Example user config
        elaraUser = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./modules/home/common-home.nix
            # etc.
          ];
        };
      });

      # ----------------------------------------------------------------------------
      # 3. DevShells (ephemeral developer environments)
      # ----------------------------------------------------------------------------
      devShells = forAllSystems (system: let
        pkgs = import nixpkgs { inherit system; };
      in {
        # Example Rust, Go, etc.
        rust = import ./modules/devshells/rust.nix { inherit pkgs; };
        go   = import ./modules/devshells/go.nix   { inherit pkgs; };
      });
    };
}
