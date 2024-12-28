{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # oh-my-zsh configuration
    oh-my-zsh = {
      enable = true;
      # Only enable core plugins to avoid plugin issues
      plugins = [ 
        "git" 
        "direnv"
        ];
    };

    initExtra = ''
      # Source zsh-autosuggestions
      source "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

      # Source zsh-syntax-highlighting
      source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

      # Source fast-syntax-highlighting
      source "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh"

      # Source zsh-autocomplete
      source "${pkgs.zsh-autocomplete}/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

      # Source Powerlevel10k theme
      source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"

      # Source Powerlevel10k instant prompt
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      # Source Powerlevel10k configuration
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      # Environment variables
      export EDITOR="vim"
      export VISUAL="vim"
      export LANG="en_US.UTF-8"
      export LC_ALL="en_US.UTF-8"
    '';

    # Shell aliases for convenience
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
      "....." = "cd ../../..";
    };
  };

  # Install required packages
  home.packages = with pkgs; [
    zsh
    oh-my-zsh
    zsh-powerlevel10k
    nerd-fonts.meslo-lg
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-fast-syntax-highlighting
    zsh-autocomplete
  ];

  # Ensure fonts are available for Powerlevel10k
  fonts.fontconfig.enable = true;

  # Copy Powerlevel10k configuration
  home.file.".p10k.zsh".source = ../../config/p10k/.p10k.zsh;
}
