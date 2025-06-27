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
      type = types.enum [ "zsh" "bash" "fish" ];
      default = "zsh";
      description = "Default shell to configure";
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
          # Modern CLI tool replacements
          ls = "eza";
          ll = "eza -l";
          la = "eza -la";
          cat = "bat";
          grep = "rg";
          find = "fd";
          
          # Git aliases
          g = "git";
          gs = "git status";
          ga = "git add";
          gc = "git commit";
          gp = "git push";
          gl = "git pull";
          
          # System aliases
          df = "duf";
          du = "dust";
          ps = "procs";
          
          # Navigation
          ".." = "cd ..";
          "..." = "cd ../..";
        };
        
        bashrcExtra = ''
          # Modern bash configuration
          export EDITOR="nvim"
          export VISUAL="nvim"
          export BROWSER="brave"
          export TERMINAL="ghostty"
          
          # Modern tools
          export BAT_THEME="TwoDark"
          export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
          
          # Development
          export GOPATH="$HOME/go"
          export GOBIN="$GOPATH/bin"
          
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

      # Fish configuration (alternative)
      fish = mkIf (config.myHome.shell.defaultShell == "fish") {
        enable = true;
        
        shellAliases = {
          # Modern CLI tool replacements
          ls = "eza";
          ll = "eza -l";
          la = "eza -la";
          cat = "bat";
          grep = "rg";
          find = "fd";
          
          # Git aliases
          g = "git";
          gs = "git status";
          ga = "git add";
          gc = "git commit";
          gp = "git push";
          gl = "git pull";
        };
        
        interactiveShellInit = ''
          # Modern fish configuration
          set -gx EDITOR nvim
          set -gx VISUAL nvim
          set -gx BROWSER brave
          set -gx TERMINAL ghostty
          
          # Modern tools
          set -gx BAT_THEME TwoDark
          set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --follow --exclude .git"
          
          # Development
          set -gx GOPATH $HOME/go
          set -gx GOBIN $GOPATH/bin
          
          # Fish-specific settings
          set fish_greeting ""
        '';
      };

      # Starship prompt (alternative to Powerlevel10k)
      starship = mkIf (config.myHome.shell.theme == "starship") {
        enable = true;
        enableZshIntegration = config.myHome.shell.defaultShell == "zsh";
        enableBashIntegration = config.myHome.shell.defaultShell == "bash";
        enableFishIntegration = config.myHome.shell.defaultShell == "fish";
        
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
        enableFishIntegration = config.myHome.shell.defaultShell == "fish";
      };

      # Modern fuzzy finder
      fzf = {
        enable = true;
        enableZshIntegration = config.myHome.shell.defaultShell == "zsh";
        enableBashIntegration = config.myHome.shell.defaultShell == "bash";
        enableFishIntegration = config.myHome.shell.defaultShell == "fish";
        
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
        enableFishIntegration = config.myHome.shell.defaultShell == "fish";
        
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
        enableFishIntegration = config.myHome.shell.defaultShell == "fish";
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
      EDITOR = "nvim";
      VISUAL = "nvim";
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
