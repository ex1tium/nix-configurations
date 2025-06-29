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
    # Note: Custom cyberdeck theme and marketplace extensions temporarily disabled
    # to fix build issues. Will be re-enabled after base system is working.
  };

  # TODO: Add cyberdeck theme from source after fixing SHA256 hash
  # cyberdeck-vscode-theme = prev.stdenv.mkDerivation {
  #   pname = "cyberdeck-vscode-theme";
  #   version = "1.0.0";
  #
  #   src = prev.fetchFromGitHub {
  #     owner = "ex1tium";
  #     repo = "cyberdeck_vscode-theme";
  #     rev = "main"; # or specific commit/tag
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

  # TODO: Re-enable after cyberdeck theme is working
  # vscode-with-cyberdeck-source = prev.vscode-with-extensions.override {
  #   vscodeExtensions = with prev.vscode-extensions; [
  #     # Core extensions (same as above)
  #     ms-vscode.cpptools
  #     ms-python.python
  #     ms-python.black-formatter
  #     golang.go
  #     rust-lang.rust-analyzer
  #     bbenoist.nix
  #     eamodio.gitlens
  #     ms-azuretools.vscode-docker
  #     ms-vscode-remote.remote-ssh
  #     ms-vscode-remote.remote-containers
  #     pkief.material-icon-theme
  #     yzhang.markdown-all-in-one
  #   ];
  #
  #   # Add cyberdeck theme as a manual extension
  #   postInstall = ''
  #     # Install cyberdeck theme
  #     mkdir -p $out/lib/vscode/resources/app/extensions/cyberdeck-theme
  #     cp -r ${final.cyberdeck-vscode-theme}/share/vscode/extensions/cyberdeck-theme/* \
  #       $out/lib/vscode/resources/app/extensions/cyberdeck-theme/
  #   '';
  # };
}
