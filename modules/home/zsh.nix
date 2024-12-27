# ZSH configuration module for home-manager
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
      plugins = [
        "git"
      ];
      theme = "powerlevel10k/powerlevel10k";
    };

    # Additional zsh plugins not included in oh-my-zsh
    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
      }
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting;
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete;
      }
    ];

    # Initialize powerlevel10k
    initExtra = ''
      # Source powerlevel10k instant prompt
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      # Source p10k config
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      # Basic environment variables
      export EDITOR="vim"
      export VISUAL="vim"
      export LANG="en_US.UTF-8"
      export LC_ALL="en_US.UTF-8"
    '';

    # Common aliases that work on any system
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
      update = "sudo nixos-rebuild switch --flake .#";
      rebuild = "sudo nixos-rebuild switch --flake .#";
      hm = "home-manager switch --flake .#";
    };
  };

  # Install powerlevel10k theme and required fonts
  home.packages = with pkgs; [
    zsh
    oh-my-zsh
    zsh-powerlevel10k
    nerd-fonts.meslo-lg
  ];

  # Copy p10k configuration
  home.file.".p10k.zsh".source = ../../config/p10k/.p10k.zsh;

  # Additional font packages for powerlevel10k
  fonts.fontconfig.enable = true;
}
