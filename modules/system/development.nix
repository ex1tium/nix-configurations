# Development environment configuration
{ config, pkgs, ... }:

{
  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Install development tools
  environment.systemPackages = with pkgs; [
    direnv
    git
    nil     # Nix language server
    nixfmt  # Nix formatter
  ];

  # Configure direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Create development shell configuration directory
  system.activationScripts.createDevShellConfig = ''
    mkdir -p /home/ex1tium/.config/nix/devshell/templates
  '';
}
