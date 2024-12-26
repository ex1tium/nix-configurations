#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------------------------
# This script initializes a multi-machine NixOS configuration repository
# folder structure, with placeholders for:
#   - flake.nix / flake.lock
#   - machines (example: Elara VM)
#   - modules (system/home/devshells/features)
#   - secrets
#   - dotfiles
#   - Overlays (optional)
#   - A basic README.md
#
# Usage:
#   1. Make this file executable (chmod +x init-nix-structure.sh).
#   2. ./init-nix-structure.sh
#   3. Commit to your Git repo (git add . && git commit -m "Init repo").
# ------------------------------------------------------------------------------

REPO_NAME="nix-configurations"
MACHINE_NAME="elara"       # Example machine name for your VM

echo "Creating top-level repository folder: ${REPO_NAME}"
mkdir -p "${REPO_NAME}"
cd "${REPO_NAME}"

# 1. Create a basic flake.nix
cat << 'EOF' > flake.nix
{
  description = "Multi-machine NixOS configuration with Home Manager, devShells, and sops-nix (PGP).";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: builtins.listToAttrs (map (system: { name = system; value = f system; }) systems);
    in
    {
      # ----------------------------------------------------------------------------
      # 1. NixOS configurations
      # ----------------------------------------------------------------------------
      nixosConfigurations = forAllSystems (system: let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in {
        # Example machine "Elara"
        elara = lib.nixosSystem {
          inherit system;
          modules = [
            ./machines/elara/configuration.nix
            # hardware-configuration.nix is imported from configuration.nix
          ];
        };
      });

      # ----------------------------------------------------------------------------
      # 2. Home Manager configurations
      # ----------------------------------------------------------------------------
      homeConfigurations = forAllSystems (system: let
        pkgs = import nixpkgs { inherit system; };
      in {
        # Example user config
        elaraUser = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./modules/home/common-home.nix
            # etc.
          ];
        };
      });

      # ----------------------------------------------------------------------------
      # 3. DevShells (ephemeral developer environments)
      # ----------------------------------------------------------------------------
      devShells = forAllSystems (system: let
        pkgs = import nixpkgs { inherit system; };
      in {
        # Example Rust, Go, etc.
        rust = import ./modules/devshells/rust.nix { inherit pkgs; };
        go   = import ./modules/devshells/go.nix   { inherit pkgs; };
      });
    };
}
EOF

# 2. Create placeholder for flake.lock
touch flake.lock

# 3. Create machines folder & Elara example
mkdir -p machines/"${MACHINE_NAME}"

# hardware-configuration.nix will be copied from your existing /etc/nixos/hardware-configuration.nix
# after you generate it on your NixOS system or copy from your current config
touch machines/"${MACHINE_NAME}"/hardware-configuration.nix

# Provide a simple configuration.nix that imports hardware-configuration.nix
cat << 'EOF' > machines/"${MACHINE_NAME}"/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Example hostname
  networking.hostName = "elara";

  # Example SSH config (using the same SSH key on all machines)
  users.users.ex1tium = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      # Replace this line with your real SSH public key(s).
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD..."
    ];
  };

  # Example usage of sops-nix + GPG
  imports = [
    "${pkgs.path}/nixos/modules/security/ssh/sshd.nix"
    ../..//modules/features/secrets.nix
  ];

  # You can store your private GPG key in an encrypted sops-nix file
  # and have NixOS place it in /home/ex1tium/.gnupg or similar location if needed.

  services.openssh.enable = true;
  # More system config ...
}
EOF

# 4. Create modules folder
mkdir -p modules/{system,home,devshells,features,overlays}
# Common system modules
cat << 'EOF' > modules/system/common.nix
{ config, pkgs, ... }:
{
  # Put common system-wide NixOS options here, e.g. timezone, locales, etc.
  time.timeZone = "Europe/Helsinki";
}
EOF

cat << 'EOF' > modules/system/networking.nix
{ config, pkgs, ... }:
{
  networking.networkmanager.enable = true;
  # Additional networking config...
}
EOF

# Common Home Manager modules
cat << 'EOF' > modules/home/common-home.nix
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
EOF

cat << 'EOF' > modules/home/shells.nix
{ config, pkgs, ... }:
{
  programs.zsh.enable = true;
  # Additional shell config
}
EOF

# DevShells
cat << 'EOF' > modules/devshells/rust.nix
{ pkgs }:
pkgs.mkShell {
  buildInputs = [
    pkgs.rustup
  ];
}
EOF

cat << 'EOF' > modules/devshells/go.nix
{ pkgs }:
pkgs.mkShell {
  buildInputs = [
    pkgs.go
  ];
}
EOF

# Features (example secrets module)
cat << 'EOF' > modules/features/secrets.nix
{ config, pkgs, ... }:
let
  sopsModule = pkgs.callPackage (fetchTarball "https://github.com/Mic92/sops-nix/tarball/master") {};
in {
  imports = [ sopsModule.modules.sops ];

  # Example: Decrypt a GPG-encrypted file that sets up a private key or secrets
  # sops.secrets."private-gpg-key" = {
  #   source = ../../secrets/private-gpg-key.asc.enc;  # Replace with your real file path
  #   user = "ex1tium";
  #   group = "ex1tium";
  #   permissions = "0400";
  # };
}
EOF

# Overlays
cat << 'EOF' > modules/overlays/custom-overlay.nix
self: super:
{
  # Example overlay: override or add new package definitions
  # e.g., custom package version or patch
}
EOF

# 5. Create secrets folder (for sops-nix-encrypted files)
mkdir -p secrets

# Example secret file
cat << 'EOF' > secrets/README.md
# Encrypted Secrets

Place your GPG-encrypted files here, e.g. *.enc.yaml, *.asc.enc, or *.json.enc.

Use \`sops\` with GPG to encrypt them, then let sops-nix handle decryption during build.
EOF

# 6. Create dotfiles folder
mkdir -p dotfiles
touch dotfiles/zshrc
touch dotfiles/gitconfig

# 7. Create optional lib folder if you want custom Nix functions
mkdir -p lib

# 8. Create a basic README
cat << EOF > README.md
# ${REPO_NAME}

This repository contains multi-machine NixOS configurations using Flakes, Home Manager, devShells, and sops-nix (with GnuPG).

## Quick Start

1. **Install NixOS** on your machine or VM.
2. **Generate hardware config** (e.g., \`nixos-generate-config --root /mnt\`).
3. **Copy** or **merge** \`hardware-configuration.nix\` into \`machines/\${MACHINE_NAME}/\`.
4. **Install** via:
   \`\`\`bash
   nixos-install --flake /mnt/etc/nixos#\${MACHINE_NAME}
   \`\`\`
5. **Pull changes** and rebuild:
   \`\`\`bash
   git pull
   sudo nixos-rebuild switch --flake .#\${MACHINE_NAME}
   \`\`\`

## Secrets

- All secrets (e.g., GPG private keys, API tokens) are stored in \`/secrets\` as encrypted files using sops-nix.
- Make sure to have the corresponding GPG private key when building or deploying.

## Home Manager

- Home Manager configs are in \`modules/home\`.
- Apply user-level configs via:
  \`\`\`bash
  home-manager switch --flake .#someUser
  \`\`\`

## DevShells

- Enter ephemeral dev environments, e.g.:
  \`\`\`bash
  nix develop .#rust
  \`\`\`

## Next Steps

- Move your existing \`configuration.nix\` and \`hardware-configuration.nix\` into \`machines/elara/\`.
- Integrate any existing logic into the shared modules (system, home, etc.).
- Update SSH keys, PGP keys, and secrets as needed.

EOF

echo "Repository structure initialized. Next steps:"
echo "1. 'cd' into ${REPO_NAME}."
echo "2. 'git init' if you haven't already done so, or 'git remote add' to connect with your GitHub repo."
echo "3. Copy your existing Elara hardware-configuration.nix into machines/elara/hardware-configuration.nix."
echo "4. Merge your existing system config into machines/elara/configuration.nix or the modules under modules/system/, etc."
echo "5. Commit and push to GitHub!"
