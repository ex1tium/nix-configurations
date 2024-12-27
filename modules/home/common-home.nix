# Common Home Manager Configuration Module
# This module defines user-specific configurations that are managed by Home Manager
# These settings will be applied to any user that includes this module

{ config, pkgs, ... }:
{
  # Import ZSH configuration
  imports = [
    ./zsh.nix
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Specify package versions
  home.stateVersion = "23.11";

  # User-specific Package Installation
  home.packages = [
    pkgs.bat    # Modern replacement for cat
    pkgs.exa    # Modern replacement for ls
    # Add more user-specific packages here
  ];

  # Dotfile Management
  # Home Manager can manage your dotfiles by linking them from a source location
  home.file = {
    # Link .zshrc from the dotfiles directory
    ".zshrc".source = ../../dotfiles/zshrc;
    
    # Example of other dotfiles you might want to manage:
    # ".gitconfig".source = ../../dotfiles/gitconfig;
    # ".vimrc".source = ../../dotfiles/vimrc;
  };

  # You can also add other Home Manager configurations here:
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
