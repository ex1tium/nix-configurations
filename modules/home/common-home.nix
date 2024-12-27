# Common home configuration module
# This module contains settings that are shared across all users

{ config, pkgs, ... }:

{
  # Import ZSH configuration
  imports = [
    ./zsh.nix
  ];

  # Enable home-manager
  programs.home-manager.enable = true;

  # Specify package versions
  home.stateVersion = "24.11";  # Use the same version as system config

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # User-specific Package Installation
  home.packages = [
    # Add more user-specific packages here
  ];

  # Dotfile Management
  # Link configuration files from the dotfiles directory
  home.file = {
    # Example of other dotfiles you might want to manage:
    # ".gitconfig".source = ../../dotfiles/gitconfig;
    # ".vimrc".source = ../../dotfiles/vimrc;
  };

  # Git Configuration Example
  # programs.git = {
  #   enable = true;
  #   userName = "Your Name";
  #   userEmail = "your.email@example.com";
  # };

  # programs.zsh = {
  #   enable = true;
  #   # ZSH specific configurations
  # };
}
