# Users NixOS Module
# User account management and configuration

{ config, lib, pkgs, globalConfig ? {}, ... }:

with lib;

{
  config = mkIf config.mySystem.enable {
    # Primary user configuration
    users.users.${config.mySystem.user} = {
      isNormalUser = true;
      description = mkDefault config.mySystem.user;
      home = mkDefault "/home/${config.mySystem.user}";

      # Base groups for all users (core groups only)
      extraGroups = mkDefault [
        "wheel"          # sudo access
        "users"          # basic user group
        "networkmanager" # network management
        "audio"          # audio devices
        "video"          # video devices
        "input"          # input devices
        "systemd-journal" # journal access
      ];

      # User shell (uses defaultUserShell from core.nix)

      # SSH keys (can be overridden per machine)
      openssh.authorizedKeys.keys = mkDefault [];

      # User packages (minimal core set)
      packages = with pkgs; mkDefault [
        # Essential user tools only
        home-manager
      ];
    };

    # Root user configuration
    users.users.root = {
      # Disable root login by default
      hashedPassword = mkDefault "!";
      openssh.authorizedKeys.keys = mkDefault [];
    };

    # User groups configuration (core groups only)
    users.groups = {
      # Ensure required groups exist
      ${config.mySystem.user} = {};
    };

    # Sudo configuration
    security.sudo = {
      enable = true;
      wheelNeedsPassword = mkDefault true;
      
      # Allow wheel group members to use sudo
      extraRules = [
        {
          groups = [ "wheel" ];
          commands = [
            {
              command = "ALL";
              options = [ "SETENV" ];
            }
          ];
        }
      ];
    };

    # User session configuration
    services.getty.autologinUser = mkDefault null; # No auto-login by default

    # Home directory permissions (defaultUserShell is set in core.nix)
    
    # User environment
    environment.homeBinInPath = true;
    
    # Core environment variables only
    environment.sessionVariables = {
      # Basic user environment
      EDITOR = mkDefault "nano";
      VISUAL = mkDefault "nano";
      PAGER = mkDefault "less";
    };



    # Basic shell configuration (detailed config in home-manager)
    programs.zsh = {
      enable = mkDefault true;
      enableCompletion = mkDefault true;
      autosuggestions.enable = mkDefault true;
      syntaxHighlighting.enable = mkDefault true;
    };

    # Bash configuration (fallback)
    programs.bash = {
      completion.enable = mkDefault true;
    };
  };
}
