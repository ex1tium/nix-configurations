# Modern Home Manager Configuration
# Simplified user-level configuration

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./common-home.nix
  ];

  # Simplified Home Manager configuration
  config = {
    # Basic Home Manager configuration
    home = {
      stateVersion = "24.11";

      # Session variables
      sessionVariables = {
        # EDITOR, BROWSER, and TERMINAL are set in zsh.nix

        # XDG directories
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_STATE_HOME = "$HOME/.local/state";
      };

      # Essential user packages (minimal set)
      packages = with pkgs; [
        # Core CLI tools
        bat
        eza
        fd
        ripgrep
        fzf
        zoxide

        # Additional packages are provided by system profiles
      ];
    };
  };
}
