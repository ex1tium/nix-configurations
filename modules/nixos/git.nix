{ config, lib, pkgs, ... }:

with lib;

{
  ### Option definitions #####################################################
  options.mySystem.git = {
    enable = mkOption {
      type = types.bool;
      default = true; # enabled by default
      description = "Enable declarative per-user Git configuration";
    };

    userName = mkOption {
      type = types.str;
      default = config.mySystem.user or "user";
      description = "Value for git user.name (global)";
      example = "Jane Doe";
    };

    userEmail = mkOption {
      type = types.str;
      default = "${config.mySystem.user}@example.com";
      description = "Value for git user.email (global)";
      example = "jane@example.com";
    };

    extraConfig = mkOption {
      type = types.attrsOf (types.attrsOf types.str);
      default = {};
      description = "Additional Git configuration merged into programs.git.config (e.g., signing, aliases).";
    };
  };

  ### Implementation ##########################################################
  config = mkIf config.mySystem.git.enable {
    programs.git = {
      enable  = true;
      package = pkgs.gitFull;

      # Attribute-set representation of ~/.gitconfig, merged with any extra sections
      config = lib.mkMerge [
        {
          user.name              = config.mySystem.git.userName;
          user.email             = config.mySystem.git.userEmail;
          init.defaultBranch     = "main";
          pull.rebase            = true;
          push.autoSetupRemote   = true;
          core.editor            = "nano";
        }
        config.mySystem.git.extraConfig
      ];
    };
  };
}
