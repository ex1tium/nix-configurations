# Modern ZSH Configuration with Powerlevel10k
# Comprehensive shell setup following current best practices

{ config, lib, pkgs, globalConfig ? {}, ... }:

with lib;

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    # Modern ZSH configuration
    defaultKeymap = "viins"; # or "viins" for vi mode

    # History configuration
    history = {
      size = 50000;
      save = 50000;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    # Oh My ZSH configuration with modern plugins
    oh-my-zsh = {
      enable = true;
      plugins = [
        # Core functionality
        "git"
        "direnv"
        "sudo"
        "command-not-found"

        # Modern development tools
        "docker"
        "docker-compose"
        "kubectl"
        "terraform"
        "aws"

        # Language-specific
        "node"
        "npm"
        "golang"
        "python"
        "rust"

        # Utilities
        "extract"
        "z" # Directory jumping
        "colored-man-pages"
        "copyfile"
        "copypath"
      ];

      # Use custom theme (Powerlevel10k will override)
      theme = "robbyrussell";
    };

    # Modern ZSH initialization
    initExtra = ''
      # Powerlevel10k instant prompt - must be at the top
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      # Load Powerlevel10k theme
      source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"

      # Enhanced ZSH plugins (beyond Home Manager built-ins)
      source "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh"
      source "${pkgs.zsh-autocomplete}/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

      # Load Powerlevel10k configuration
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      # Modern environment variables
      export EDITOR="nano"
      export VISUAL="nano"
      export BROWSER="${config.home.sessionVariables.BROWSER or "brave"}"
      export TERMINAL="ghostty"
      export LANG="en_US.UTF-8"
      export LC_ALL="en_US.UTF-8"

      # Development environment
      export GOPATH="$HOME/go"
      export GOBIN="$GOPATH/bin"
      export CARGO_HOME="$HOME/.cargo"
      export RUSTUP_HOME="$HOME/.rustup"

      # Modern tool configurations
      export BAT_THEME="TwoDark"
      export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
      export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

      # ZSH-specific optimizations
      setopt AUTO_CD              # Change directory without cd
      setopt CORRECT              # Correct typos
      setopt HIST_VERIFY          # Verify history expansion
      setopt SHARE_HISTORY        # Share history between sessions
      setopt APPEND_HISTORY       # Append to history file
      setopt INC_APPEND_HISTORY   # Append immediately
      setopt HIST_IGNORE_DUPS     # Ignore duplicate commands
      setopt HIST_IGNORE_SPACE    # Ignore commands starting with space
      setopt GLOB_DOTS            # Include dotfiles in globbing

      # Modern completion settings
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
      zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'

      # Load additional completions
      autoload -Uz compinit
      compinit

      # Custom functions
      function mkcd() {
        mkdir -p "$1" && cd "$1"
      }

      function extract() {
        if [ -f $1 ] ; then
          case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
          esac
        else
          echo "'$1' is not a valid file"
        fi
      }

      # Git functions
      function gclone() {
        git clone "$1" && cd "$(basename "$1" .git)"
      }

      # Development shortcuts
      function serve() {
        local port=''${1:-8000}
        python3 -m http.server $port
      }

      function weather() {
        curl -s "wttr.in/''${1:-Helsinki}?format=3"
      }
    '';

    # Modern shell aliases
    shellAliases = {
      # Modern CLI tool replacements
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      tree = "eza --tree";
      cat = "bat";
      grep = "rg";
      find = "fd";

      # Navigation shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # Git aliases
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      gco = "git checkout";
      gb = "git branch";
      glog = "git log --oneline --graph --decorate";

      # Development aliases
      dc = "docker-compose";
      k = "kubectl";
      tf = "terraform";

      # System aliases
      df = "duf";
      du = "dust";
      ps = "procs";
      top = "btop";

      # Network aliases
      ping = "ping -c 5";
      wget = "wget -c";

      # Safety aliases
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";

      # Convenience aliases
      h = "history";
      j = "jobs";
      c = "clear";
      e = "$EDITOR";

      # Directory shortcuts
      home = "cd ~";
      docs = "cd ~/Documents";
      downloads = "cd ~/Downloads";
      desktop = "cd ~/Desktop";

      # Development shortcuts
      dev = "cd ~/Development";
      projects = "cd ~/Projects";

      # Quick edits
      zshrc = "$EDITOR ~/.zshrc";
      vimrc = "$EDITOR ~/.vimrc";

      # System information
      myip = "curl -s https://ipinfo.io/ip";
      localip = "ip route get 1.1.1.1 | awk '{print $7}'";

      # Package management (if on NixOS)
      nrs = "sudo nixos-rebuild switch";
      nrb = "sudo nixos-rebuild boot";
      nrt = "sudo nixos-rebuild test";
      nfu = "nix flake update";
      nfc = "nix flake check";

      # Home Manager
      hms = "home-manager switch";
      hmb = "home-manager build";
    };
  };

  # Install required packages
  home.packages = with pkgs; [
    # ZSH and theme
    zsh
    oh-my-zsh
    zsh-powerlevel10k

    # Fonts for Powerlevel10k
    (nerdfonts.override { fonts = [ "FiraCode" "Meslo" ]; })

    # Enhanced ZSH plugins
    zsh-fast-syntax-highlighting  # Enhanced syntax highlighting
    zsh-autocomplete              # Enhanced completion
    zsh-history-substring-search  # Better history search

    # Modern CLI tools that integrate with ZSH
    bat                           # Better cat
    eza                           # Better ls
    fd                            # Better find
    ripgrep                       # Better grep
    fzf                           # Fuzzy finder
    zoxide                        # Better cd

    # Development tools
    git
    gh                            # GitHub CLI

    # System tools
    htop
    btop
    tree
    wget
    curl

    # Modern system alternatives
    duf                           # Better df
    dust                          # Better du
    procs                         # Better ps
  ];

  # Ensure fonts are available for Powerlevel10k
  fonts.fontconfig.enable = true;

  # Copy Powerlevel10k configuration from existing setup
  home.file.".p10k.zsh".source = ../../config/p10k/.p10k.zsh;

  # Modern ZSH configuration files
  home.file.".config/ripgrep/config".text = ''
    # Ripgrep configuration
    --type-add
    web:*.{html,css,js,jsx,ts,tsx,vue,svelte}
    --type-add
    config:*.{json,yaml,yml,toml,ini,conf}
    --smart-case
    --follow
    --hidden
    --glob=!.git/*
    --glob=!node_modules/*
    --glob=!target/*
    --glob=!.next/*
    --glob=!dist/*
    --glob=!build/*
  '';

  # Modern shell environment
  home.sessionVariables = {
    # ZSH-specific
    HISTSIZE = "50000";
    SAVEHIST = "50000";
    HISTFILE = "$HOME/.zsh_history";

    # Modern tools
    BAT_THEME = "TwoDark";
    FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
    FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --inline-info";
    RIPGREP_CONFIG_PATH = "$HOME/.config/ripgrep/config";

    # Development
    EDITOR = mkDefault "nano";
    VISUAL = mkDefault "nano";
    BROWSER = mkDefault "brave";
    TERMINAL = mkDefault "ghostty";

    # Language-specific
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";

    # Node.js
    NODE_OPTIONS = "--max-old-space-size=8192";

    # Python
    PYTHONDONTWRITEBYTECODE = "1";
    PYTHONUNBUFFERED = "1";
  };
}
