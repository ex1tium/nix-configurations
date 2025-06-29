# Development Feature Module
# Implements development tools and environment when enabled

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./development/vscode.nix
  ];
  config = mkIf config.mySystem.features.development.enable {
    # Essential Development Packages (using shared collections)
    environment.systemPackages =
      let
        packages = import ../packages/common.nix { inherit pkgs; };
      in
      packages.developmentCore ++
      packages.buildTools ++
      packages.cliTools ++
      packages.developmentCli ++
      packages.debuggingTools ++
      packages.developmentNetwork ++
      packages.archiveTools ++
      packages.developmentArchive ++
      packages.developmentMonitoring ++
      packages.textProcessing ++
      packages.versionControl ++
      packages.documentationTools ++
      # Language-specific packages are added per-machine as needed
      # This allows for flexible development environments without bloating base profiles
      # Example: Add nodejs, go, python3, rust, etc. in machine-specific configurations

      # GUI Development Tools are handled by the vscode.nix module
      # Additional tools like dbeaver, postman, etc. should be added per-machine
      [];

    # Development Services
    # Note: Databases (PostgreSQL, MySQL, Redis) should be run in containers
    # Use Docker/Podman compose files or development shells for database services
    services = {
      # No database services - use containers instead
    };

    # Development Environment Variables
    environment.sessionVariables = {
      # Development Paths
      GOPATH = "$HOME/go";
      GOBIN = "$HOME/go/bin";
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";
      
      # Node.js
      NODE_OPTIONS = "--max-old-space-size=8192";
      
      # Build Optimization
      MAKEFLAGS = "-j$(nproc)";
      
      # Rust
      RUST_BACKTRACE = "1";
      
      # Go
      GO111MODULE = "on";
      GOPROXY = "https://proxy.golang.org,direct";
      GOSUMDB = "sum.golang.org";
      CGO_ENABLED = "1";
      
      # Python
      PYTHONPATH = "$HOME/.local/lib/python3.11/site-packages:$PYTHONPATH";

      # Container development
      DOCKER_BUILDKIT = "1";
      COMPOSE_DOCKER_CLI_BUILD = "1";

      # XDG directories for development tools
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      
      # Nix Development
      NIX_PATH = mkDefault "nixpkgs=${pkgs.path}";
    };

    # Development Programs
    programs = {
      # Nix Development
      nix-ld.enable = true;
      
      # Shell Integration
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      
      # Git Configuration
      git = {
        enable = true;
        config = {
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
          core.editor = "nano";
          merge.tool = "nano";
          diff.tool = "nano";
          diff.algorithm = "patience";
          merge.conflictstyle = "diff3";
          core.preloadindex = true;
          core.fscache = true;
          gc.auto = 256;
        };
      };
    };

    # User Configuration for Development
    users.users.${config.mySystem.user}.extraGroups = [
      "dialout"     # Serial port access
      "plugdev"     # USB device access
    ];



    # Firewall Rules for Development
    # Note: Database ports removed - databases should run in containers
    networking.firewall.allowedTCPPorts = [
      3000    # React/Node.js dev server
      3001    # Alternative dev server
      4000    # Ruby on Rails
      5000    # Flask/Django dev server
      8000    # Python dev server
      8080    # Common dev server
      8888    # Jupyter notebook
      9000    # Various dev tools
      9090    # Prometheus
      # Database ports removed - use containers with port mapping as needed
    ];

    # Development-specific Kernel Parameters
    boot.kernel.sysctl = {
      # Increase file watchers for development tools
      "fs.inotify.max_user_watches" = mkDefault 524288;
      "fs.inotify.max_user_instances" = mkDefault 256;
      
      # Increase file descriptors
      "fs.file-max" = mkDefault 2097152;

      # Network development
      "net.core.rmem_max" = mkDefault 134217728;
      "net.core.wmem_max" = mkDefault 134217728;
    };

    # Development Shell Aliases
    programs.zsh.shellAliases = {
      # Git shortcuts
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      gb = "git branch";
      gco = "git checkout";
      
      # Development shortcuts
      serve = "python3 -m http.server";
      jsonpp = "jq .";
      yamlpp = "yq .";
      
      # Modern CLI tools
      cat = "bat";
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      tree = "eza --tree";
      grep = "rg";
      find = "fd";
      
      # System shortcuts
      rebuild = "sudo nixos-rebuild switch --flake .";
      update = "nix flake update";
      clean = "sudo nix-collect-garbage -d";
    };

    # Development Documentation
    documentation = {
      enable = true;
      man.enable = true;
      info.enable = true;
      doc.enable = true;
      nixos.enable = true;
    };

    # Programming Fonts
    fonts.packages = with pkgs; [
      fira-code
      fira-code-symbols
      jetbrains-mono
      source-code-pro
      # Updated nerdfonts to new package structure
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.sauce-code-pro
    ];
  };
}
