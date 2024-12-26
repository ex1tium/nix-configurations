# nix-configurations

This repository contains multi-machine NixOS configurations using Flakes, Home Manager, devShells, and sops-nix (with GnuPG).

## Quick Start

1. **Install NixOS** on your machine or VM.
2. **Generate hardware config** (e.g., `nixos-generate-config --root /mnt`).
3. **Copy** or **merge** `hardware-configuration.nix` into `machines/${MACHINE_NAME}/`.
4. **Install** via:
   ```bash
   nixos-install --flake /mnt/etc/nixos#${MACHINE_NAME}
   ```
5. **Pull changes** and rebuild:
   ```bash
   git pull
   sudo nixos-rebuild switch --flake .#${MACHINE_NAME}
   ```

## Secrets

- All secrets (e.g., GPG private keys, API tokens) are stored in `/secrets` as encrypted files using sops-nix.
- Make sure to have the corresponding GPG private key when building or deploying.

## Home Manager

- Home Manager configs are in `modules/home`.
- Apply user-level configs via:
  ```bash
  home-manager switch --flake .#someUser
  ```

## DevShells

- Enter ephemeral dev environments, e.g.:
  ```bash
  nix develop .#rust
  ```

## Next Steps

- Move your existing `configuration.nix` and `hardware-configuration.nix` into `machines/elara/`.
- Integrate any existing logic into the shared modules (system, home, etc.).
- Update SSH keys, PGP keys, and secrets as needed.

