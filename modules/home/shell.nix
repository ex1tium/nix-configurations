# Modern Shell Configuration Module
# Handles shell selection and configuration based on user preferences

{ config, lib, pkgs, globalConfig ? {}, ... }:

with lib;

{
  imports = [
    ./zsh.nix
  ];

  options.myHome.shell = {
    enable = mkEnableOption "shell configuration" // { default = true; };
    
    defaultShell = mkOption {
      type = types.enum [ "zsh" "bash" ];
      default = "zsh";
      description = "Default shell to configure (ZSH or Bash only)";
    };
    
    theme = mkOption {
      type = types.enum [ "powerlevel10k" "starship" "oh-my-zsh" ];
      default = "powerlevel10k";
      description = "Shell theme to use";
    };
  };

  config = mkIf config.myHome.shell.enable {
    # Configure the selected shell
    programs = {
      # ZSH configuration (primary)
      zsh = mkIf (config.myHome.shell.defaultShell == "zsh") {
        enable = true;
        # Additional ZSH configuration is handled in zsh.nix
      };

      # Bash configuration (fallback)
      bash = mkIf (config.myHome.shell.defaultShell == "bash") {
        enable = true;
        enableCompletion = true;
        
        historyControl = [ "ignoredups" "ignorespace" ];
        historySize = 50000;
        historyFileSize = 50000;
        
        shellAliases = {
          # Modern CLI tool replacements (identical to ZSH)
          ls = "eza";
          ll = "eza -l";
          la = "eza -la";
          tree = "eza --tree";
          cat = "bat";
          grep = "rg";
          find = "fd";

          # Navigation shortcuts (identical to ZSH)
          ".." = "cd ..";
          "..." = "cd ../..";
          "...." = "cd ../../..";
          "....." = "cd ../../../..";

          # Git aliases (identical to ZSH)
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

          # Development aliases (identical to ZSH)
          dc = "docker-compose";
          k = "kubectl";
          tf = "terraform";

          # System aliases (identical to ZSH)
          df = "duf";
          du = "dust";
          ps = "procs";
          top = "btop";

          # Network aliases (identical to ZSH)
          ping = "ping -c 5";
          wget = "wget -c";

          # Safety aliases (identical to ZSH)
          rm = "rm -i";
          cp = "cp -i";
          mv = "mv -i";

          # Convenience aliases (identical to ZSH)
          h = "history";
          j = "jobs";
          c = "clear";
          e = "$EDITOR";

          # Directory shortcuts (identical to ZSH)
          home = "cd ~";
          docs = "cd ~/Documents";
          downloads = "cd ~/Downloads";
          desktop = "cd ~/Desktop";

          # Development shortcuts (identical to ZSH)
          dev = "cd ~/Development";
          projects = "cd ~/Projects";

          # Quick edits (identical to ZSH)
          zshrc = "$EDITOR ~/.zshrc";
          vimrc = "$EDITOR ~/.vimrc";

          # System information (identical to ZSH)
          myip = "curl -s https://ipinfo.io/ip";
          localip = "ip route get 1.1.1.1 | awk '{print $7}'";

          # Package management (identical to ZSH)
          nrs = "sudo nixos-rebuild switch";
          nrb = "sudo nixos-rebuild boot";
          nrt = "sudo nixos-rebuild test";
          nfu = "nix flake update";
          nfc = "nix flake check";

          # Home Manager (identical to ZSH)
          hms = "home-manager switch";
          hmb = "home-manager build";
        };
        
        bashrcExtra = ''
          # Modern bash configuration (identical to ZSH)
          export EDITOR="nano"
          export VISUAL="nano"
          export BROWSER="brave"
          export TERMINAL="ghostty"

          # Modern tools (identical to ZSH)
          export BAT_THEME="TwoDark"
          export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"

          # Development (identical to ZSH)
          export GOPATH="$HOME/go"
          export GOBIN="$GOPATH/bin"

          # Functions (identical to ZSH)
          function mkcd() {
            mkdir -p "$1" && cd "$1"
          }

          function extract() {
            if [ -f "$1" ]; then
              case "$1" in
                *.tar.bz2)   tar xjf "$1"     ;;
                *.tar.gz)    tar xzf "$1"     ;;
                *.bz2)       bunzip2 "$1"    ;;
                *.rar)       unrar x "$1"    ;;
                *.gz)        gunzip "$1"     ;;
                *.tar)       tar xf "$1"     ;;
                *.tbz2)      tar xjf "$1"    ;;
                *.tgz)       tar xzf "$1"    ;;
                *.zip)       unzip "$1"      ;;
                *.Z)         uncompress "$1" ;;
                *.7z)        7z x "$1"       ;;
                *)           echo "'$1' cannot be extracted via extract()" ;;
              esac
            else
              echo "'$1' is not a valid file"
            fi
          }

          function gclone() {
            git clone "$1" && cd "$(basename "$1" .git)"
          }

          function serve() {
            local port=''${1:-8000}
            python3 -m http.server $port
          }

          function weather() {
            curl -s "wttr.in/''${1:-Helsinki}?format=3"
          }

          # Bash-specific settings
          shopt -s histappend
          shopt -s checkwinsize
          shopt -s cdspell
          shopt -s dirspell
          shopt -s globstar

          # Load additional completions
          if [ -f /etc/bash_completion ]; then
            . /etc/bash_completion
          fi
        '';
      };

      # Starship prompt (experimental alternative to Powerlevel10k)
      starship = mkIf (config.myHome.shell.theme == "starship") {
        enable = true;
        enableZshIntegration = config.myHome.shell.defaultShell == "zsh";
        enableBashIntegration = config.myHome.shell.defaultShell == "bash";
        
        settings = {
          format = "$all$character";
          
          character = {
            success_symbol = "[➜](bold green)";
            error_symbol = "[➜](bold red)";
          };
          
          git_branch = {
            format = "[$symbol$branch]($style) ";
            symbol = " ";
          };
          
          git_status = {
            format = "([\\[$all_status$ahead_behind\\]]($style) )";
          };
          
          cmd_duration = {
            format = "[$duration]($style) ";
            style = "yellow";
          };
          
          directory = {
            truncation_length = 3;
            truncate_to_repo = true;
          };
          
          nodejs = {
            format = "[$symbol($version )]($style)";
            symbol = " ";
          };
          
          python = {
            format = "[$symbol$pyenv_prefix($version )($virtualenv )]($style)";
            symbol = " ";
          };
          
          rust = {
            format = "[$symbol($version )]($style)";
            symbol = " ";
          };
          
          golang = {
            format = "[$symbol($version )]($style)";
            symbol = " ";
          };
        };
      };

      # Modern directory jumper
      zoxide = {
        enable = true;
        enableZshIntegration = config.myHome.shell.defaultShell == "zsh";
        enableBashIntegration = config.myHome.shell.defaultShell == "bash";
      };

      # Modern fuzzy finder
      fzf = {
        enable = true;
        enableZshIntegration = config.myHome.shell.defaultShell == "zsh";
        enableBashIntegration = config.myHome.shell.defaultShell == "bash";
        
        defaultCommand = "fd --type f --hidden --follow --exclude .git";
        defaultOptions = [
          "--height 40%"
          "--layout=reverse"
          "--border"
          "--inline-info"
          "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
        ];
        
        historyWidgetOptions = [
          "--sort"
          "--exact"
        ];
      };

      # Modern ls replacement
      eza = {
        enable = true;
        enableZshIntegration = config.myHome.shell.defaultShell == "zsh";
        enableBashIntegration = config.myHome.shell.defaultShell == "bash";
        
        extraOptions = [
          "--group-directories-first"
          "--header"
          "--git"
        ];
      };

      # Modern cat replacement
      bat = {
        enable = true;
        config = {
          theme = "TwoDark";
          style = "numbers,changes,header";
          pager = "less -FR";
        };
      };

      # Directory environment manager
      direnv = {
        enable = true;
        enableZshIntegration = config.myHome.shell.defaultShell == "zsh";
        enableBashIntegration = config.myHome.shell.defaultShell == "bash";
        nix-direnv.enable = true;
      };
    };

    # Shell-specific packages
    home.packages = with pkgs; [
      # Modern CLI tools
      bat
      eza
      fd
      ripgrep
      fzf
      zoxide
      
      # System monitoring
      htop
      btop
      
      # Modern alternatives
      duf      # Better df
      dust     # Better du
      procs    # Better ps
      tokei    # Code statistics
      
      # Network tools
      curl
      wget
      httpie
      
      # File management
      tree
      ranger
      nnn
      
      # Archive tools
      unzip
      zip
      p7zip
      
      # Text processing
      jq
      yq
      
      # Development tools
      git
      gh
    ];

    # Shell environment variables
    home.sessionVariables = {
      # Editor preferences
      EDITOR = "nano";
      VISUAL = "nano";
      BROWSER = "brave";
      TERMINAL = "ghostty";
      
      # Modern tool configurations
      BAT_THEME = "TwoDark";
      FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
      FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --inline-info";
      RIPGREP_CONFIG_PATH = "$HOME/.config/ripgrep/config";
      
      # Development paths
      GOPATH = "$HOME/go";
      GOBIN = "$HOME/go/bin";
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";
      
      # Shell theme
      SHELL_THEME = config.myHome.shell.theme;
    };
  };
}
