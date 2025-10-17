# Modern Home Manager Configuration
# Simplified user-level configuration

{ config, pkgs, ... }:

{
  imports = [
    ./common-home.nix
  ];

  # Simplified Home Manager configuration
  config = {
    # Basic Home Manager configuration
    home = {
      stateVersion = "25.05";

      # Session variables
      sessionVariables = {
        # EDITOR, BROWSER, and TERMINAL are set in zsh.nix

        # XDG directories
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_STATE_HOME = "$HOME/.local/state";
      };

      # Essential user packages (using shared collections)
      packages =
        let
          packages = import ../packages/common.nix { inherit pkgs; };
        in
        packages.homeCliTools;

        # Additional packages are provided by system profiles
    };
  };
}
