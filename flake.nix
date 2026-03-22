# Modern NixOS Configuration Flake - Version 25.05
# Centralized version management system

{
  description = "Modern NixOS configuration system with machine profiles - Version 25.05";

  # Centralized Version Management
  # Change these URLs to update NixOS version across entire configuration
  inputs = {
    # NixOS 25.05 (unstable) - as per user preference
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Stable fallback for compatibility
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      flake-utils,
      ...
    }:
    let
      # Global configuration with centralized version management
      globalConfig = {
        defaultUser = "ex1tium";
        defaultTimezone = "Europe/Helsinki";
        defaultLocale = "en_US.UTF-8";
        defaultStateVersion = "25.05"; # NixOS 25.05 (unstable)
        nixosVersion = "25.05";
      };

      # Machine configurations
      machines = {
        elara = {
          system = "x86_64-linux";
          profile = "developer";
          hostname = "elara";
          users = [ globalConfig.defaultUser ];
          # Features are now configured in the profile modules
          # Machine-specific overrides can be added in machine configuration
        };

        magos = {
          system = "x86_64-linux";
          profile = "base";
          hostname = "magos";
          user = "magos";
          users = [ "magos" ];
        };

        magos-rescue = {
          system = "x86_64-linux";
          profile = "rescue";
          hostname = "magos-rescue";
          user = "magos";
          users = [ "magos" ];
          enableHomeManager = false;
          enableSops = false;
        };

        magos-rescue-cli = {
          system = "x86_64-linux";
          profile = "rescue-cli";
          hostname = "magos-rescue-cli";
          user = "magos";
          users = [ "magos" ];
          enableHomeManager = false;
          enableSops = false;
        };
      };

      # Helper function to create system configurations
      mkSystem =
        {
          hostname,
          system ? "x86_64-linux",
        }:
        let
          machineConfig = machines.${hostname};
          primaryUser = machineConfig.user or globalConfig.defaultUser;
          profileModule = ./modules/profiles/${machineConfig.profile}.nix;
          enableHomeManager = machineConfig.enableHomeManager or true;
          enableSops = machineConfig.enableSops or true;

          # Hardware configuration resolution:
          # 1. During installation: use freshly generated /mnt/etc/nixos/hardware-configuration.nix
          # 2. After installation: use committed machines/${hostname}/hardware-configuration.nix
          machineHwConfig = ./machines/${hostname}/hardware-configuration.nix;
          installHwConfig = /mnt/etc/nixos/hardware-configuration.nix;

          hardwareModule =
            if builtins.pathExists installHwConfig then
              installHwConfig
            else if builtins.pathExists machineHwConfig then
              machineHwConfig
            else
              throw "No hardware configuration found for ${hostname}. Run nixos-generate-config first.";
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              self
              nixpkgs
              home-manager
              sops-nix
              ;
            inherit globalConfig machineConfig;
          };
          modules =
            [
              # Apply custom overlays
              { nixpkgs.overlays = [ (import ./modules/overlays/custom-overlay.nix) ]; }

              # Hardware configuration (actual or template)
              hardwareModule

              # Machine-specific configuration
              ./machines/${hostname}/configuration.nix

              # Profile configuration (base, desktop, developer, or server)
              profileModule

            ]
            ++ nixpkgs.lib.optionals enableHomeManager [
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.${primaryUser} = import ./modules/home/default.nix;
                };
              }
            ]
            ++ nixpkgs.lib.optionals enableSops [
              sops-nix.nixosModules.sops
            ];
        };
    in
    {
      # NixOS system configurations
      nixosConfigurations = nixpkgs.lib.mapAttrs (
        name: machineConfig:
        mkSystem {
          hostname = name;
          inherit (machineConfig) system;
        }
      ) machines;

    }
    // flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        mkScriptApp = name: description: text:
          let
            drv = pkgs.writeShellScriptBin name text;
          in
          {
            type = "app";
            program = "${drv}/bin/${name}";
            meta = {
              inherit description;
            };
          };
      in
      {
        # Development shells
        devShells = {
          default = pkgs.mkShell {
            name = "nix-config-dev";
            buildInputs = with pkgs; [
              nixd
              nixfmt
              deadnix
              statix
              git
              gh
            ];
            shellHook = ''
              echo "🔧 Modern Nix Configuration Development Environment"
              echo "Available tools: nixd, nixfmt, deadnix, statix"
            '';
          };

          nodejs = import ./modules/devshells/nodejs.nix { inherit pkgs; };
          go = import ./modules/devshells/go.nix { inherit pkgs; };
          python = import ./modules/devshells/python.nix { inherit pkgs; };
          rust = import ./modules/devshells/rust.nix { inherit pkgs; };
        };

        formatter = pkgs.nixfmt;

        apps = {
          update = mkScriptApp "update" "Update flake inputs and refresh the lockfile" ''
              echo "🔄 Updating flake inputs..."
              nix flake update --commit-lock-file
              echo "✅ Flake inputs updated and committed!"
            '';

          check = mkScriptApp "check" "Run flake checks for all configured systems" ''
              echo "🔍 Checking configuration..."
              nix flake check --all-systems
              echo "✅ Configuration check completed!"
            '';

          upgrade-check = mkScriptApp "upgrade-check" "Update inputs and test a rebuild for the current host" ''
              set -euo pipefail

              echo "🔍 Checking for updates..."
              nix flake update --commit-lock-file

              echo "📊 Recent changes:"
              ${pkgs.git}/bin/git log --oneline -5 flake.lock || true

              echo "🧪 Testing build for current machine..."
              hostname=$(${pkgs.hostname}/bin/hostname)
              sudo nixos-rebuild build --flake .#$hostname

              echo "✅ Ready to apply with: sudo nixos-rebuild switch --flake .#$hostname"
              echo "📚 See docs/UPGRADE_GUIDE.md for detailed procedures"
            '';

          deploy = mkScriptApp "deploy" "Build and switch the NixOS configuration for the current host" ''
              set -euo pipefail

              hostname=$(${pkgs.hostname}/bin/hostname)
              echo "🚀 Deploying configuration for $hostname..."

              # Build first to catch errors
              sudo nixos-rebuild build --flake .#$hostname

              # Apply configuration
              sudo nixos-rebuild switch --flake .#$hostname

              echo "✅ Deployment completed!"
              echo "📋 Check system status with: systemctl --failed"
            '';
        };
      }
    );
}
