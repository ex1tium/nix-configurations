{ pkgs }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    # Go toolchain
    go
    gopls        # Go language server
    go-tools     # Additional Go tools
    delve        # Go debugger
    golangci-lint # Linter

    # Generic development tools
    git
    gnumake
  ];

  shellHook = ''
    echo "🚀 Go development environment loaded!"
    echo "Available tools: go, gopls, dlv, golangci-lint"
  '';
}
