{ config, pkgs, ... }:
{
  # Example user-level settings or dotfiles
  home.packages = [
    pkgs.bat
    pkgs.exa
  ];

  # Example to include your .zshrc or p10k theme from dotfiles
  home.file.".zshrc".source = ../../dotfiles/zshrc;
}
