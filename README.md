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

## GPG Key Setup

### Initial Setup (Per Machine)
1. **Prepare GPG directory**:
   ```bash
   # Create fresh GPG directory
   mkdir -m 700 ~/.gnupg
   
   # Configure GPG
   cat > ~/.gnupg/gpg.conf << EOF
   use-agent
   pinentry-mode loopback
   EOF
   
   cat > ~/.gnupg/gpg-agent.conf << EOF
   allow-loopback-pinentry
   enable-ssh-support
   EOF
   
   chmod 600 ~/.gnupg/gpg.conf ~/.gnupg/gpg-agent.conf
   ```

2. **Import keys**:
   ```bash
   # Import public key first
   gpg --import path/to/public-key.asc
   
   # Import private key
   gpg --allow-secret-key-import --import path/to/private-key.asc
   
   # Set trust level
   gpg --edit-key your.email@example.com
   > trust
   > 5
   > y
   > quit
   ```

3. **Verify setup**:
   ```bash
   # Test signing
   echo "test" | gpg --clearsign
   
   # Check key details
   gpg -K --with-keygrip
   ```

### Git Signing Configuration
```bash
git config --global user.signingkey your.email@example.com
git config --global commit.gpgsign true
```

## Secrets

- All secrets are stored in `/secrets` as encrypted files using sops-nix
- Secrets are encrypted using GPG keys configured in `.sops.yaml`
- Make sure to have the corresponding GPG private key when building or deploying

## Home Manager

- Home Manager configs are in `modules/home`
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

- Move your existing `configuration.nix` and `hardware-configuration.nix` into `machines/elara/`
- Integrate any existing logic into the shared modules (system, home, etc.)
- Update SSH keys, PGP keys, and secrets as needed
