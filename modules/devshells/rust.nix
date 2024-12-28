{ pkgs }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    # Rust toolchain
    rustc
    cargo
    rust-analyzer  # Rust language server
    clippy        # Linter
    rustfmt       # Formatter

    # Build dependencies
    pkg-config
    openssl
    
    # Generic development tools
    git
    gnumake
  ];

  shellHook = ''
    echo "🦀 Rust development environment loaded!"
    echo "Available tools: rustc, cargo, rust-analyzer, clippy, rustfmt"
  '';
}
