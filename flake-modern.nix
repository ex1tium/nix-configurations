# Modern NixOS Configuration Flake - Working Version
# Simplified structure to ensure it builds correctly

{
  description = "Modern NixOS configuration system with machine profiles";

  inputs = {
    # Use stable nixpkgs to avoid compatibility issues
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, flake-utils, ... }:
  let
    # Global configuration
    globalConfig = {
      defaultUser = "ex1tium";
      defaultTimezone = "Europe/Helsinki";
      defaultLocale = "en_US.UTF-8";
      defaultStateVersion = "24.11";
    };

    # Machine configurations
    machines = {
      elara = {
        system = "x86_64-linux";
        profile = "developer";
        hostname = "elara";
        users = [ globalConfig.defaultUser ];
        features = {
          desktop = { enable = true; environment = "plasma"; };
          development = { enable = true; };
          virtualization = { enable = true; };
          server = { enable = false; };
        };
      };
    };

    # Helper function to create system configurations
    mkSystem = { hostname, system ? "x86_64-linux", features ? {} }:
      let
        machineConfig = machines.${hostname};
      in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self nixpkgs home-manager sops-nix;
          inherit globalConfig machineConfig;
          finalFeatures = features;
        };
        modules = [
          # Hardware configuration
          ./machines/${hostname}/hardware-configuration.nix
          
          # Basic system configuration
          {
            # Basic system settings
            networking.hostName = hostname;
            time.timeZone = globalConfig.defaultTimezone;
            i18n.defaultLocale = globalConfig.defaultLocale;
            system.stateVersion = globalConfig.defaultStateVersion;

            # Basic Nix configuration
            nix = {
              settings = {
                experimental-features = [ "nix-command" "flakes" ];
                auto-optimise-store = true;
                trusted-users = [ "root" "@wheel" ];
              };
              package = nixpkgs.legacyPackages.${system}.nixVersions.latest;
            };

            # Basic boot configuration
            boot.loader = {
              systemd-boot.enable = true;
              efi.canTouchEfiVariables = true;
            };

            # User configuration
            users.users.${globalConfig.defaultUser} = {
              isNormalUser = true;
              description = globalConfig.defaultUser;
              extraGroups = [ "wheel" "networkmanager" ];
              home = "/home/${globalConfig.defaultUser}";
            };

            # Basic packages
            environment.systemPackages = with nixpkgs.legacyPackages.${system}; [
              vim
              git
              curl
              wget
              firefox
              
              # Modern CLI tools
              nano
              bat
              eza
              fd
              ripgrep
              fzf
              zoxide
              htop
              btop
            ];

            # Enable NetworkManager
            networking.networkmanager.enable = true;

            # Enable sound
            security.rtkit.enable = true;
            services.pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
            };

            # Desktop environment (if enabled)
            services.displayManager.sddm.enable = features.desktop.enable or false;
            services.desktopManager.plasma6.enable = features.desktop.enable or false;
            services.xserver = {
              enable = features.desktop.enable or false;
              xkb = {
                layout = "us";
                variant = "";
              };
            };

            # Development tools (if enabled)
            programs.nix-ld.enable = features.development.enable or false;
            
            # Virtualization (if enabled)
            virtualisation.docker.enable = features.virtualization.enable or false;
            virtualisation.libvirtd.enable = features.virtualization.enable or false;
          }

          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${globalConfig.defaultUser} = { pkgs, ... }: {
                home = {
                  stateVersion = globalConfig.defaultStateVersion;
                  username = globalConfig.defaultUser;
                  homeDirectory = "/home/${globalConfig.defaultUser}";

                  packages = with pkgs; [
                    bat
                    eza
                    fd
                    ripgrep
                    fzf
                    zoxide
                  ];
                };

                programs.zsh = {
                  enable = true;
                  autosuggestion.enable = true;
                  syntaxHighlighting.enable = true;
                  enableCompletion = true;

                  shellAliases = {
                    ls = "eza";
                    ll = "eza -l";
                    la = "eza -la";
                    cat = "bat";
                    grep = "rg";
                    find = "fd";
                  };
                };
              };
            };
          }

          # Secrets management
          sops-nix.nixosModules.sops
          {
            sops = {
              defaultSopsFile = ./secrets/secrets.yaml;
              validateSopsFiles = false;
              age.keyFile = "/home/${globalConfig.defaultUser}/.config/sops/age/keys.txt";
            };
          }
        ];
      };
  in
  {
    # NixOS system configurations
    nixosConfigurations = nixpkgs.lib.mapAttrs (name: machineConfig:
      mkSystem {
        hostname = name;
        inherit (machineConfig) system features;
      }
    ) machines;

  } // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { 
        inherit system; 
        config.allowUnfree = true;
      };
    in
    {
      # Development shells
      devShells = {
        default = pkgs.mkShell {
          name = "nix-config-dev";
          buildInputs = with pkgs; [
            nixd
            nixfmt-rfc-style
            deadnix
            statix
            git
            gh
          ];
          shellHook = ''
            echo "🔧 Modern Nix Configuration Development Environment"
            echo "Available tools: nixd, nixfmt-rfc-style, deadnix, statix"
          '';
        };
        
        nodejs = import ./modules/devshells/nodejs.nix { inherit pkgs; };
        go = import ./modules/devshells/go.nix { inherit pkgs; };
        python = import ./modules/devshells/python.nix { inherit pkgs; };
        rust = import ./modules/devshells/rust.nix { inherit pkgs; };
      };

      formatter = pkgs.nixfmt-rfc-style;
      
      apps = {
        update = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "update" ''
            nix flake update
            echo "✅ Flake inputs updated!"
          '';
        };
        
        check = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "check" ''
            nix flake check --all-systems
            echo "✅ Configuration check completed!"
          '';
        };
      };
    }
  );
}
