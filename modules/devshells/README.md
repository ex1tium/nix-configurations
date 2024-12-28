# Development Shells

This directory contains development shell configurations for various programming languages and development environments. These shells provide isolated environments with all necessary tools and dependencies for development.

## Available Development Shells

- [`go.nix`](./go.nix) - Go development environment with:
  - Go toolchain
  - gopls (Language Server)
  - delve (Debugger)
  - golangci-lint (Linter)
  - Additional development tools

- [`rust.nix`](./rust.nix) - Rust development environment with:
  - Rust toolchain
  - rust-analyzer (Language Server)
  - clippy (Linter)
  - rustfmt (Formatter)
  - Common build dependencies

## System Setup

To use these development shells across your NixOS machines:

1. Add the following to your NixOS configuration (usually in `configuration.nix` or a dedicated module):

```nix
{ config, pkgs, ... }: {
  # Enable nix flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Install direnv
  environment.systemPackages = with pkgs; [
    direnv
  ];
  
  # Configure shell for direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
```

2. Create the central devshell configuration:

```bash
mkdir -p ~/.config/nix/devshell
```

Add the following to `~/.config/nix/devshell/flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  
  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system} = {
      go = import /home/ex1tium/nix-configurations/modules/devshells/go.nix { inherit pkgs; };
      rust = import /home/ex1tium/nix-configurations/modules/devshells/rust.nix { inherit pkgs; };
    };
  };
}
```

## Usage

### Setting Up a New Project

1. Create a new project directory:
```bash
mkdir -p ~/projects/my-project
cd ~/projects/my-project
```

2. Add a `.envrc` file:
```bash
# For Go projects:
echo 'use flake "/home/ex1tium/.config/nix/devshell#go"' > .envrc

# For Rust projects:
echo 'use flake "/home/ex1tium/.config/nix/devshell#rust"' > .envrc
```

3. Allow direnv:
```bash
direnv allow
```

### VS Code Integration

1. Install the "Remote - SSH" extension in VS Code
2. Install the "direnv" extension
3. When opening a project folder, VS Code will automatically:
   - Load the development environment
   - Configure language servers
   - Set up debugging

### Git Integration

To keep your project repository clean:

1. Add to `.gitignore`:
```
.envrc
.direnv/
```

2. (Optional) Provide a template `.envrc.example` for other Nix users:
```bash
cp .envrc .envrc.example
```

## Adding New Development Shells

1. Create a new file in this directory (e.g., `python.nix`)
2. Define the development shell using `pkgs.mkShell`
3. Add the new shell to `~/.config/nix/devshell/flake.nix`
4. Create a template in `~/.config/nix/devshell/templates/`

## Troubleshooting

If you encounter issues:

1. Ensure direnv is allowed: `direnv allow`
2. Check if the flake is accessible: `nix flake show ~/.config/nix/devshell`
3. Verify the development shell loads: `nix develop ~/.config/nix/devshell#go`
