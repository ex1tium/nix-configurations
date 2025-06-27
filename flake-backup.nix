# Modern NixOS Configuration Flake
# Comprehensive multi-machine system with Desktop/Developer/Server profiles
# Following current Nix ecosystem best practices and conventions

{
  description = "Modern NixOS configuration system with machine profiles, typed modules, and comprehensive tooling";

  # Modern input specification with explicit versioning and follows patterns
  inputs = {
    # Primary package source - nixos-unstable for latest features
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Stable fallback for critical systems
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Home Manager for user environment management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Modern secrets management with age and GPG support
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flake utilities for system abstraction
    flake-utils.url = "github:numtide/flake-utils";

    # Hardware-specific configurations and optimizations
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Modern development tools
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Modern outputs using flake-utils and comprehensive machine profiles
  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, sops-nix, flake-utils, nixos-hardware, devenv, ... }:
  let
    # Use flake-utils for proper system abstraction
    inherit (flake-utils.lib) eachDefaultSystem;

    # Global configuration constants
    globalConfig = {
      defaultUser = "ex1tium";
      defaultTimezone = "Europe/Helsinki";
      defaultLocale = "en_US.UTF-8";
      defaultStateVersion = "24.11";

      # Default shell configuration
      shell = {
        default = "zsh";
        theme = "powerlevel10k";
        font = "FiraCode Nerd Font Mono";
      };
    };

    # Machine Profile Definitions
    machineProfiles = {
      # Desktop Profile - lightweight, basic usage
      desktop = {
        description = "Lightweight desktop for basic usage and thin clients";
        features = {
          desktop.enable = true;
          desktop.environment = "plasma"; # or "xfce" for low-spec
          development.enable = false;
          server.enable = false;
          gaming.enable = false;
          virtualization.enable = false;
        };
        packages = {
          browsers = [ "brave" "firefox" ];
          remote = [ "remmina" ];
          hardware = [ "solaar" ];
          media = [ "vlc" ];
          graphics = [ "gimp" ];
          transfer = [ "filezilla" ];
          terminal = [ "tmux" "irssi" "ghostty" ];
          compatibility = [ "bottles" ];
          utilities = [ "balenaetcher" ];
        };
      };

      # Developer Profile - full-featured workstation
      developer = {
        description = "Full development workstation with all capabilities";
        features = {
          desktop.enable = true;
          desktop.environment = "plasma";
          development.enable = true;
          server.enable = true;
          gaming.enable = false;
          virtualization.enable = true;
        };
        packages = {
          # Inherits all desktop packages plus:
          development = [ "vscode" "cyberdeck-theme" ];
          languages = [ "nodejs-lts" "go" "python" ];
          vcs = [ "git" "gh" "advanced-git-tools" ];
          containers = [ "docker" "podman" "docker-compose" ];
          network = [ "advanced-debugging-tools" ];
        };
      };

      # Server Profile - headless, containerized services
      server = {
        description = "Headless server for containers and virtualization";
        features = {
          desktop.enable = false;
          development.enable = false;
          server.enable = true;
          gaming.enable = false;
          virtualization.enable = true;
        };
        packages = {
          containers = [ "docker" "podman" "docker-compose" ];
          virtualization = [ "qemu" "kvm" "libvirt" ];
          monitoring = [ "system-monitoring" ];
          security = [ "enhanced-firewall" ];
        };
      };
    };

    # Machine-specific configurations
    machines = {
      elara = {
        system = "x86_64-linux";
        profile = "developer";  # Use developer profile
        hostname = "elara";
        users = [ globalConfig.defaultUser ];

        # Machine-specific overrides
        hardware = {
          kernel = "latest"; # or "lts"
          enableVirtualization = true;
          enableRemoteDesktop = true;
        };

        # Custom feature overrides
        features = {
          # Inherit from developer profile but customize
          gaming.enable = false;
        };
      };
    };

    # Modern library functions
    lib = nixpkgs.lib.extend (final: prev: {
      myLib = {
        # Helper to create system configurations with profiles
        mkSystem = { hostname, profile, system ? "x86_64-linux", users ? [ globalConfig.defaultUser ], features ? {}, hardware ? {} }:
          let
            profileConfig = machineProfiles.${profile};
            machineConfig = machines.${hostname};

            # Merge profile features with machine-specific overrides
            finalFeatures = profileConfig.features // features // (machineConfig.features or {});
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit self nixpkgs nixpkgs-stable home-manager sops-nix nixos-hardware;
              inherit globalConfig profileConfig machineConfig finalFeatures;
              lib = nixpkgs.lib;
            };
            modules = [
              # Core system configuration
              ./machines/${hostname}/configuration.nix

              # Modern modular system
              ./modules/profiles/${profile}.nix
              ./modules/nixos

              # Hardware-specific optimizations
              (if hardware.enableVirtualization or false
               then ./modules/nixos/virtualization.nix
               else {})

              # Home Manager integration
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = {
                    inherit globalConfig profileConfig finalFeatures;
                  };
                  users = lib.genAttrs users (user: ./modules/home);
                };
              }

              # Secrets management
              sops-nix.nixosModules.sops
              ./modules/nixos/security.nix
            ];
          };
      };
    });
  in
  {
    # Modern NixOS system configurations using machine profiles
    nixosConfigurations = lib.mapAttrs (name: machineConfig:
      lib.myLib.mkSystem {
        hostname = name;
        profile = machineConfig.profile;
        inherit (machineConfig) system users features hardware;
      }
    ) machines;

    # Standalone Home Manager configurations (for non-NixOS systems)
    homeConfigurations = lib.mapAttrs (user: _:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        modules = [ ./modules/home ];
        extraSpecialArgs = {
          inherit globalConfig;
          profileConfig = machineProfiles.developer; # Default to developer
          finalFeatures = machineProfiles.developer.features;
        };
      }
    ) (lib.genAttrs [ globalConfig.defaultUser ] (_: {}));

  } // eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # Modern development shells with comprehensive tooling
      devShells = {
        # Default development environment for this configuration
        default = pkgs.mkShell {
          name = "nix-config-dev";
          buildInputs = with pkgs; [
            # Modern Nix tooling
            nixd                    # Language server
            nixfmt-rfc-style       # RFC-style formatter
            deadnix                # Dead code detection
            statix                 # Static analysis
            nix-tree               # Dependency visualization
            nix-diff               # Configuration diffing

            # Development tools
            git
            gh
            just                   # Command runner
          ];
          shellHook = ''
            echo "🔧 Modern Nix Configuration Development Environment"
            echo "Available tools: nixd, nixfmt-rfc-style, deadnix, statix, nix-tree"
            echo "Machine profiles: desktop, developer, server"
            echo ""
            echo "Quick commands:"
            echo "  nix flake check --all-systems  # Validate configuration"
            echo "  deadnix --check .             # Check for dead code"
            echo "  statix check .                # Static analysis"
          '';
        };

        # Language-specific development environments
        nodejs = import ./modules/devshells/nodejs.nix { inherit pkgs; };
        go = import ./modules/devshells/go.nix { inherit pkgs; };
        python = import ./modules/devshells/python.nix { inherit pkgs; };
        rust = import ./modules/devshells/rust.nix { inherit pkgs; };
      };

      # Modern formatting and linting
      formatter = pkgs.nixfmt-rfc-style;

      # Utility applications
      apps = {
        # Update flake inputs
        update = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "update" ''
            echo "🔄 Updating flake inputs..."
            nix flake update
            echo "✅ Flake inputs updated successfully!"
          '';
        };

        # Comprehensive configuration check
        check = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "check" ''
            echo "🔍 Running comprehensive configuration checks..."
            nix flake check --all-systems
            deadnix --check .
            statix check .
            echo "✅ All checks completed!"
          '';
        };
      };
    }
  ) // {
    # Global overlays for custom packages
    overlays.default = final: prev: {
      # Custom package overlays and modifications
    };

    # Reusable NixOS modules
    nixosModules = {
      default = ./modules/nixos;
      profiles = {
        desktop = ./modules/profiles/desktop.nix;
        developer = ./modules/profiles/developer.nix;
        server = ./modules/profiles/server.nix;
      };
    };

    # Reusable Home Manager modules
    homeManagerModules = {
      default = ./modules/home;
      shell = ./modules/home/shell.nix;
      development = ./modules/home/development.nix;
    };
  };
}
