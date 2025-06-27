# Modern Home Manager Configuration
# User-level configuration with proper options and modularity

{ config, lib, pkgs, globalConfig, profileConfig, finalFeatures, osConfig ? {}, ... }:

with lib;

{
  imports = [
    ./shell.nix
    ./development.nix
    ./desktop.nix
    ./git.nix
  ];

  # Modern Home Manager options
  options.myHome = {
    enable = mkEnableOption "custom home configuration" // { default = true; };
    
    username = mkOption {
      type = types.str;
      default = globalConfig.defaultUser;
      description = "Username for home configuration";
    };

    homeDirectory = mkOption {
      type = types.str;
      default = "/home/${config.myHome.username}";
      description = "Home directory path";
    };

    stateVersion = mkOption {
      type = types.str;
      default = globalConfig.defaultStateVersion;
      description = "Home Manager state version";
    };

    features = {
      desktop = mkEnableOption "desktop applications and configuration";
      development = mkEnableOption "development tools and configuration";
      gaming = mkEnableOption "gaming applications";
      media = mkEnableOption "media applications";
    };

    shell = {
      name = mkOption {
        type = types.enum [ "zsh" "bash" "fish" ];
        default = "zsh";
        description = "Default shell";
      };
      
      theme = mkOption {
        type = types.enum [ "powerlevel10k" "starship" "oh-my-zsh" ];
        default = "powerlevel10k";
        description = "Shell theme";
      };
    };
  };

  config = mkIf config.myHome.enable {
    # Basic Home Manager configuration
    home = {
      username = config.myHome.username;
      homeDirectory = config.myHome.homeDirectory;
      stateVersion = config.myHome.stateVersion;

      # Modern session variables
      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        BROWSER = "brave";
        TERMINAL = "ghostty";
        
        # XDG directories
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_STATE_HOME = "$HOME/.local/state";
        
        # Development
        CARGO_HOME = "$XDG_DATA_HOME/cargo";
        RUSTUP_HOME = "$XDG_DATA_HOME/rustup";
        GOPATH = "$XDG_DATA_HOME/go";
        GOBIN = "$XDG_DATA_HOME/go/bin";
        
        # Modern tools
        BAT_THEME = "TwoDark";
        FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
        RIPGREP_CONFIG_PATH = "$XDG_CONFIG_HOME/ripgrep/config";
        
        # Shell configuration
        SHELL_THEME = config.myHome.shell.theme;
      };

      # Essential user packages based on profile
      packages = with pkgs; [
        # Modern CLI tools (shared base)
        bat
        eza
        fd
        ripgrep
        fzf
        zoxide
        
        # File management
        ranger
        nnn
        
        # System monitoring
        htop
        btop
        
        # Network tools
        curl
        wget
        httpie
        
        # Archive tools
        unzip
        zip
        p7zip
        
        # Text processing
        jq
        yq
        
        # Modern alternatives
        duf      # Better df
        dust     # Better du
        procs    # Better ps
        tokei    # Code statistics
        
        # Font
        (nerdfonts.override { fonts = [ "FiraCode" ]; })
        
      ] ++ optionals (finalFeatures.desktop.enable or false) [
        # Desktop applications based on profile
        brave
        firefox
        thunderbird
        
        # Media
        vlc
        mpv
        
        # Graphics
        gimp
        inkscape
        
        # Office
        libreoffice-qt6-fresh
        
        # Communication
        discord
        signal-desktop
        
        # File managers
        dolphin
        
        # Remote access
        remmina
        freerdp
        
        # Hardware management
        solaar
        
        # File transfer
        filezilla
        
        # Terminal
        tmux
        irssi
        ghostty
        
        # Compatibility
        bottles
        
        # Utilities
        balenaetcher
        
      ] ++ optionals (finalFeatures.development.enable or false) [
        # Development tools
        vscode
        neovim
        
        # Version control
        git
        gh
        
        # Containers
        docker-compose
        
      ] ++ optionals (config.myHome.features.gaming) [
        # Gaming
        steam
        lutris
        
      ] ++ optionals (config.myHome.features.media) [
        # Media creation
        obs-studio
        audacity
        blender
      ];
    };

    # Modern program configurations
    programs = {
      # Enable Home Manager
      home-manager.enable = true;

      # Modern file manager
      ranger = {
        enable = true;
        settings = {
          preview_images = true;
          preview_images_method = "kitty";
        };
      };

      # Modern terminal multiplexer
      tmux = {
        enable = true;
        clock24 = true;
        keyMode = "vi";
        mouse = true;
        
        extraConfig = ''
          # Modern tmux configuration
          set -g default-terminal "screen-256color"
          set -ga terminal-overrides ",*256col*:Tc"
          
          # Better prefix
          unbind C-b
          set -g prefix C-a
          bind C-a send-prefix
          
          # Better splits
          bind | split-window -h
          bind - split-window -v
          
          # Vi mode
          setw -g mode-keys vi
          bind-key -T copy-mode-vi v send-keys -X begin-selection
          bind-key -T copy-mode-vi y send-keys -X copy-selection
        '';
      };

      # Modern fuzzy finder
      fzf = {
        enable = true;
        enableZshIntegration = config.myHome.shell.name == "zsh";
        enableBashIntegration = config.myHome.shell.name == "bash";
        enableFishIntegration = config.myHome.shell.name == "fish";
        
        defaultCommand = "fd --type f --hidden --follow --exclude .git";
        defaultOptions = [
          "--height 40%"
          "--layout=reverse"
          "--border"
          "--inline-info"
        ];
      };

      # Modern directory jumper
      zoxide = {
        enable = true;
        enableZshIntegration = config.myHome.shell.name == "zsh";
        enableBashIntegration = config.myHome.shell.name == "bash";
        enableFishIntegration = config.myHome.shell.name == "fish";
      };

      # Modern cat replacement
      bat = {
        enable = true;
        config = {
          theme = "TwoDark";
          style = "numbers,changes,header";
        };
      };

      # Modern ls replacement
      eza = {
        enable = true;
        enableZshIntegration = config.myHome.shell.name == "zsh";
        enableBashIntegration = config.myHome.shell.name == "bash";
        enableFishIntegration = config.myHome.shell.name == "fish";
        
        extraOptions = [
          "--group-directories-first"
          "--header"
        ];
      };
    };

    # Modern service management
    services = {
      # GPG agent
      gpg-agent = {
        enable = true;
        enableSshSupport = true;
        pinentryPackage = if (finalFeatures.desktop.enable or false)
                         then pkgs.pinentry-gtk2 
                         else pkgs.pinentry-curses;
        
        defaultCacheTtl = 28800;
        maxCacheTtl = 86400;
      };

      # Modern notification daemon (desktop only)
      dunst = mkIf (finalFeatures.desktop.enable or false) {
        enable = true;
        settings = {
          global = {
            monitor = 0;
            follow = "mouse";
            geometry = "300x5-30+20";
            indicate_hidden = "yes";
            shrink = "no";
            transparency = 0;
            notification_height = 0;
            separator_height = 2;
            padding = 8;
            horizontal_padding = 8;
            frame_width = 3;
            frame_color = "#aaaaaa";
            separator_color = "frame";
            sort = "yes";
            idle_threshold = 120;
            font = "FiraCode Nerd Font Mono 10";
            line_height = 0;
            markup = "full";
            format = "<b>%s</b>\\n%b";
            alignment = "left";
            show_age_threshold = 60;
            word_wrap = "yes";
            ellipsize = "middle";
            ignore_newline = "no";
            stack_duplicates = true;
            hide_duplicate_count = false;
            show_indicators = "yes";
            icon_position = "left";
            max_icon_size = 32;
            sticky_history = "yes";
            history_length = 20;
            browser = "brave";
            always_run_script = true;
            title = "Dunst";
            class = "Dunst";
            startup_notification = false;
            verbosity = "mesg";
            corner_radius = 0;
          };
        };
      };
    };

    # Modern XDG configuration
    xdg = {
      enable = true;
      
      userDirs = mkIf (finalFeatures.desktop.enable or false) {
        enable = true;
        createDirectories = true;
        
        desktop = "$HOME/Desktop";
        documents = "$HOME/Documents";
        download = "$HOME/Downloads";
        music = "$HOME/Music";
        pictures = "$HOME/Pictures";
        videos = "$HOME/Videos";
        templates = "$HOME/Templates";
        publicShare = "$HOME/Public";
      };

      mimeApps = mkIf (finalFeatures.desktop.enable or false) {
        enable = true;
        defaultApplications = {
          "text/html" = "brave-browser.desktop";
          "x-scheme-handler/http" = "brave-browser.desktop";
          "x-scheme-handler/https" = "brave-browser.desktop";
          "x-scheme-handler/about" = "brave-browser.desktop";
          "x-scheme-handler/unknown" = "brave-browser.desktop";
          "application/pdf" = "brave-browser.desktop";
          "image/jpeg" = "gwenview.desktop";
          "image/png" = "gwenview.desktop";
          "video/mp4" = "vlc.desktop";
          "audio/mpeg" = "vlc.desktop";
        };
      };
    };

    # Enable features based on configuration
    myHome.development.enable = mkDefault (finalFeatures.development.enable or false);
    myHome.desktop.enable = mkDefault (finalFeatures.desktop.enable or false);
    myHome.features = {
      desktop = finalFeatures.desktop.enable or false;
      development = finalFeatures.development.enable or false;
      gaming = finalFeatures.gaming.enable or false;
      media = config.myHome.features.media;
    };
  };
}
