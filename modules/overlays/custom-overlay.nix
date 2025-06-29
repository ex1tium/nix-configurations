self: super:
{
  # Import VS Code overlay with cyberdeck theme
  inherit (import ./vscode-overlay.nix self super)
    vscode-with-cyberdeck
    cyberdeck-vscode-theme
    vscode-with-cyberdeck-source;

  # Example overlay: override or add new package definitions
  # e.g., custom package version or patch
}
