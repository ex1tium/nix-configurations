# VS Code Development Feature Module
# Configures VS Code with cyberdeck theme and development extensions

{ config, lib, pkgs, ... }:

with lib;

{
  config = mkIf (config.mySystem.features.development.enable && elem "vscode" config.mySystem.features.development.editors) {
    
    # VS Code with custom extensions
    environment.systemPackages = with pkgs; [
      # Use the custom VS Code with cyberdeck theme
      vscode-with-cyberdeck
    ];

    # VS Code system configuration
    environment.etc."vscode/settings.json".text = builtins.toJSON {
      # Theme Configuration
      "workbench.colorTheme" = "Cyberdeck";
      "workbench.iconTheme" = "material-icon-theme";
      
      # Editor Configuration
      "editor.fontFamily" = "'FiraCode Nerd Font Mono', 'JetBrains Mono', 'Fira Code', monospace";
      "editor.fontLigatures" = true;
      "editor.fontSize" = 14;
      "editor.lineHeight" = 1.5;
      "editor.fontWeight" = "400";
      "editor.cursorBlinking" = "smooth";
      "editor.cursorSmoothCaretAnimation" = "on";
      "editor.smoothScrolling" = true;
      
      # Cyberdeck-specific settings
      "editor.bracketPairColorization.enabled" = true;
      "editor.guides.bracketPairs" = "active";
      "editor.inlineSuggest.enabled" = true;
      "editor.suggestSelection" = "first";
      
      # Terminal Configuration
      "terminal.integrated.fontFamily" = "'FiraCode Nerd Font Mono', 'JetBrains Mono'";
      "terminal.integrated.fontSize" = 13;
      "terminal.integrated.lineHeight" = 1.2;
      "terminal.integrated.cursorBlinking" = true;
      "terminal.integrated.cursorStyle" = "line";
      "terminal.integrated.shell.linux" = "${pkgs.zsh}/bin/zsh";
      
      # File Explorer
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;
      "explorer.compactFolders" = false;
      
      # Git Configuration
      "git.enableSmartCommit" = true;
      "git.confirmSync" = false;
      "git.autofetch" = true;
      "gitlens.currentLine.enabled" = false;
      "gitlens.hovers.currentLine.over" = "line";
      
      # Language-specific settings
      "python.defaultInterpreterPath" = "${pkgs.python3}/bin/python";
      "python.formatting.provider" = "black";
      "python.linting.enabled" = true;
      "python.linting.pylintEnabled" = true;
      
      "go.toolsManagement.autoUpdate" = true;
      "go.useLanguageServer" = true;
      
      "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
      "rust-analyzer.checkOnSave.command" = "clippy";
      
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
      
      # TypeScript/JavaScript
      "typescript.updateImportsOnFileMove.enabled" = "always";
      "javascript.updateImportsOnFileMove.enabled" = "always";
      "eslint.autoFixOnSave" = true;
      "prettier.requireConfig" = true;
      
      # Docker
      "docker.showStartPage" = false;
      
      # Performance
      "files.watcherExclude" = {
        "**/.git/objects/**" = true;
        "**/.git/subtree-cache/**" = true;
        "**/node_modules/*/**" = true;
        "**/.hg/store/**" = true;
        "**/target/**" = true;
        "**/.cargo/**" = true;
      };
      
      # Security
      "security.workspace.trust.untrustedFiles" = "open";
      "security.workspace.trust.banner" = "never";
      
      # Telemetry (disabled for privacy)
      "telemetry.telemetryLevel" = "off";
      "redhat.telemetry.enabled" = false;
      
      # Extensions
      "extensions.autoUpdate" = false;
      "extensions.autoCheckUpdates" = false;
      
      # Cyberdeck theme specific enhancements
      "workbench.tree.indent" = 20;
      "workbench.tree.renderIndentGuides" = "always";
      "editor.renderWhitespace" = "boundary";
      "editor.renderControlCharacters" = true;
      "editor.minimap.enabled" = true;
      "editor.minimap.renderCharacters" = false;
      "editor.minimap.maxColumn" = 120;
      
      # Better Comments configuration
      "better-comments.tags" = [
        {
          "tag" = "!";
          "color" = "#FF2D00";
          "strikethrough" = false;
          "underline" = false;
          "backgroundColor" = "transparent";
          "bold" = false;
          "italic" = false;
        }
        {
          "tag" = "?";
          "color" = "#3498DB";
          "strikethrough" = false;
          "underline" = false;
          "backgroundColor" = "transparent";
          "bold" = false;
          "italic" = false;
        }
        {
          "tag" = "//";
          "color" = "#474747";
          "strikethrough" = true;
          "underline" = false;
          "backgroundColor" = "transparent";
          "bold" = false;
          "italic" = false;
        }
        {
          "tag" = "todo";
          "color" = "#FF8C00";
          "strikethrough" = false;
          "underline" = false;
          "backgroundColor" = "transparent";
          "bold" = false;
          "italic" = false;
        }
        {
          "tag" = "*";
          "color" = "#98C379";
          "strikethrough" = false;
          "underline" = false;
          "backgroundColor" = "transparent";
          "bold" = false;
          "italic" = false;
        }
      ];
    };

    # VS Code keybindings
    environment.etc."vscode/keybindings.json".text = builtins.toJSON [
      {
        "key" = "ctrl+shift+t";
        "command" = "workbench.action.terminal.new";
      }
      {
        "key" = "ctrl+shift+`";
        "command" = "workbench.action.terminal.toggleTerminal";
      }
      {
        "key" = "ctrl+shift+p";
        "command" = "workbench.action.showCommands";
      }
      {
        "key" = "ctrl+p";
        "command" = "workbench.action.quickOpen";
      }
      {
        "key" = "ctrl+shift+f";
        "command" = "workbench.action.findInFiles";
      }
    ];

    # User-level VS Code configuration via Home Manager
    home-manager.users.${config.mySystem.user} = {
      programs.vscode = {
        enable = false; # We use system-level installation
      };
      
      # Create user settings directory and link system config
      home.file.".config/Code/User/settings.json".source = 
        config.environment.etc."vscode/settings.json".source;
      home.file.".config/Code/User/keybindings.json".source = 
        config.environment.etc."vscode/keybindings.json".source;
    };

    # Install cyberdeck theme fonts
    fonts.packages = with pkgs; [
      fira-code
      fira-code-symbols
      jetbrains-mono
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    ];
  };
}
