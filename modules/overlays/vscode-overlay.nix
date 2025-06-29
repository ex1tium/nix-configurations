# VS Code Overlay with Custom Extensions and Cyberdeck Theme
# This overlay provides a customized VS Code installation with the cyberdeck theme

final: prev: {
  # Custom VS Code with cyberdeck theme and essential extensions
  vscode-with-cyberdeck = prev.vscode-with-extensions.override {
    vscodeExtensions = with prev.vscode-extensions; [
      # Language Support
      ms-vscode.cpptools
      ms-python.python
      ms-python.black-formatter
      ms-python.isort
      ms-python.pylint
      ms-vscode.cmake-tools
      
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
      mhutchie.git-graph
      
      # Docker
      ms-azuretools.vscode-docker
      
      # Kubernetes
      ms-kubernetes-tools.vscode-kubernetes-tools
      
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
      
    ] ++ prev.vscode-utils.extensionsFromVscodeMarketplace [
      # Custom Cyberdeck Theme from GitHub
      {
        name = "cyberdeck-vscode-theme";
        publisher = "ex1tium";
        version = "latest";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will be updated
        # Note: This will need to be built from your GitHub repository
      }
      
      # Additional extensions not in nixpkgs
      {
        name = "better-comments";
        publisher = "aaron-bond";
        version = "3.0.2";
        sha256 = "sha256-hQmA8PWjf2Nd60v5EAuqqD8LIEu7slrNs8luc3ePgZc=";
      }
      
      {
        name = "indent-rainbow";
        publisher = "oderwat";
        version = "8.3.1";
        sha256 = "sha256-6jXqEN0Hm3QE0a8SZAJjp7UW8+Wr8Uy8Xk8Uy8Xk8Uy=";
      }
      
      {
        name = "todo-tree";
        publisher = "gruntfuggly";
        version = "0.0.226";
        sha256 = "sha256-3QKsZCBqlVNqOkj0xhcVdwYLS2PBJUqwfIeTO1QbPMo=";
      }
      
      {
        name = "error-lens";
        publisher = "usernamehw";
        version = "3.16.0";
        sha256 = "sha256-Y3M/A5rYLkxQPRIZ0BUjhlkvixDae+dJdewjw0EaXzk=";
      }
    ];
  };

  # Alternative: Build cyberdeck theme from source
  cyberdeck-vscode-theme = prev.stdenv.mkDerivation {
    pname = "cyberdeck-vscode-theme";
    version = "1.0.0";
    
    src = prev.fetchFromGitHub {
      owner = "ex1tium";
      repo = "cyberdeck_vscode-theme";
      rev = "main"; # or specific commit/tag
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update with actual hash
    };
    
    installPhase = ''
      mkdir -p $out/share/vscode/extensions/cyberdeck-theme
      cp -r * $out/share/vscode/extensions/cyberdeck-theme/
    '';
    
    meta = with prev.lib; {
      description = "Cyberdeck theme for VS Code";
      homepage = "https://github.com/ex1tium/cyberdeck_vscode-theme";
      license = licenses.mit;
      maintainers = [ "ex1tium" ];
    };
  };

  # VS Code with cyberdeck theme built from source
  vscode-with-cyberdeck-source = prev.vscode-with-extensions.override {
    vscodeExtensions = with prev.vscode-extensions; [
      # Core extensions (same as above)
      ms-vscode.cpptools
      ms-python.python
      ms-python.black-formatter
      golang.go
      rust-lang.rust-analyzer
      bbenoist.nix
      eamodio.gitlens
      ms-azuretools.vscode-docker
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-containers
      pkief.material-icon-theme
      yzhang.markdown-all-in-one
    ];
    
    # Add cyberdeck theme as a manual extension
    postInstall = ''
      # Install cyberdeck theme
      mkdir -p $out/lib/vscode/resources/app/extensions/cyberdeck-theme
      cp -r ${final.cyberdeck-vscode-theme}/share/vscode/extensions/cyberdeck-theme/* \
        $out/lib/vscode/resources/app/extensions/cyberdeck-theme/
    '';
  };
}
