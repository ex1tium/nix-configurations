# Development Feature Module
# Implements development tools and environment when enabled

{ config, lib, pkgs, ... }:

with lib;

{
  config = mkIf config.mySystem.features.development.enable {
    # Essential Development Packages
    environment.systemPackages = with pkgs; [
      # Core Development Tools
      git
      gh
      git-lfs
      git-crypt
      
      # Build Tools
      gnumake
      cmake
      pkg-config
      autoconf
      automake
      libtool
      gcc
      clang
      llvm
      
      # Modern CLI Tools
      bat
      eza
      fd
      ripgrep
      fzf
      zoxide
      direnv
      just
      jq
      yq
      
      # Debugging Tools
      gdb
      lldb
      strace
      ltrace
      valgrind
      
      # Network Tools
      curl
      wget
      httpie
      netcat
      socat
      
      # Archive Tools
      zip
      unzip
      p7zip
      gnutar
      gzip
      
      # System Monitoring
      htop
      btop
      iotop
      
      # File Tools
      tree
      file
      which
      lsof
      
      # Text Processing
      gnused
      gawk
      gnugrep
      
      # Version Control
      mercurial
      subversion
      
      # Documentation
      man-pages
      man-pages-posix
    ] ++ optionals (elem "nodejs" config.mySystem.features.development.languages) [
      # Node.js Development
      nodejs_latest
      nodePackages.npm
      nodePackages.yarn
      nodePackages.pnpm
      nodePackages.typescript-language-server
      nodePackages.eslint
      nodePackages.prettier
      nodePackages.nodemon
    ] ++ optionals (elem "go" config.mySystem.features.development.languages) [
      # Go Development
      go
      gopls
      go-tools
      delve
      golangci-lint
    ] ++ optionals (elem "python" config.mySystem.features.development.languages) [
      # Python Development
      python3
      python3Packages.pip
      poetry
      python3Packages.virtualenv
      python3Packages.black
      python3Packages.flake8
      python3Packages.mypy
      pyright
    ] ++ optionals (elem "rust" config.mySystem.features.development.languages) [
      # Rust Development
      rustc
      cargo
      rust-analyzer
      clippy
      rustfmt
    ] ++ optionals (elem "nix" config.mySystem.features.development.languages) [
      # Nix Development
      nixd
      nixpkgs-fmt
      statix
    ] ++ optionals (elem "vscode" config.mySystem.features.development.editors) [
      # VS Code
      vscode-with-extensions
    ] ++ optionals config.mySystem.features.desktop.enable [
      # GUI Development Tools (only if desktop is enabled)
      dbeaver-bin
      postman
      insomnia
      wireshark
    ];

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
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "SourceCodePro" ]; })
    ];
  };
}
