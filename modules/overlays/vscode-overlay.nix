# VS Code Overlay with Essential Extensions
# This overlay provides a working VS Code installation with core extensions

final: prev: {
  # Custom VS Code with essential extensions (cyberdeck theme will be added later)
  vscode-with-cyberdeck = prev.vscode-with-extensions.override {
    vscodeExtensions = with prev.vscode-extensions; [
      # Language Support
      ms-python.python
      ms-python.black-formatter

      # JavaScript/TypeScript
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint

      # Go
      golang.go

      # Rust
      rust-lang.rust-analyzer

      # Nix
      bbenoist.nix

      # Git
      eamodio.gitlens

      # Docker
      ms-azuretools.vscode-docker

      # Remote Development
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-containers

      # Productivity
      redhat.vscode-yaml
      
      # Themes and UI
      pkief.material-icon-theme

      # Markdown
      yzhang.markdown-all-in-one

      # Bracket Pair Colorizer (built-in in newer versions)
      # coenraads.bracket-pair-colorizer-2

    ];
    # Note: Cyberdeck theme is available from VS Code Marketplace
    # Install from: https://marketplace.visualstudio.com/items?itemName=ex1tium.cyberdeck-2025
    # Or from GitHub: https://github.com/ex1tium/cyberdeck-2025_vscode_theme
    # The theme is configured in modules/features/development/vscode.nix via VS Code settings.
  };

  # Cyberdeck theme from source (currently disabled - use marketplace theme instead)
  # To enable: uncomment below, update SHA256 hash, and update vscode-with-extensions
  # cyberdeck-vscode-theme = prev.stdenv.mkDerivation {
  #   pname = "cyberdeck-vscode-theme";
  #   version = "1.0.0";
  #
  #   src = prev.fetchFromGitHub {
  #     owner = "ex1tium";
  #     repo = "cyberdeck_vscode-theme";
  #     rev = "main";
  #     sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update with actual hash
  #   };
  #
  #   installPhase = ''
  #     mkdir -p $out/share/vscode/extensions/cyberdeck-theme
  #     cp -r * $out/share/vscode/extensions/cyberdeck-theme/
  #   '';
  #
  #   meta = with prev.lib; {
  #     description = "Cyberdeck theme for VS Code";
  #     homepage = "https://github.com/ex1tium/cyberdeck_vscode-theme";
  #     license = licenses.mit;
  #     maintainers = [ "ex1tium" ];
  #   };
  # };
}
