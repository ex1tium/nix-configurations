# nix-configurations

This repository contains multi-machine NixOS configurations using Flakes, Home Manager, devShells, and sops-nix (with GnuPG).

## Repository Structure

```
.
├── bash-scripts          # Scripts for initializing Nix structure and other utilities
│   └── init-nix-structure.sh
├── config                # Configuration files for various tools
│   └── p10k             # Powerlevel10k configuration
├── dotfiles             # User dotfiles for various applications
│   └── gitconfig        # Git configuration file
├── flake.lock           # Lock file for Nix flakes
├── flake.nix            # Main flake file for Nix configuration
├── machines             # Machine-specific configurations
│   └── elara           # Configuration for the 'elara' machine
│       ├── configuration.nix         # Main configuration for Elara
│       └── hardware-configuration.nix # Hardware-specific settings
├── modules              # Modular configurations for various features
│   ├── devshells        # Development shell configurations
│   │   ├── go.nix       # Go development environment
│   │   ├── README.md    # Documentation for development shells
│   │   └── rust.nix     # Rust development environment
│   ├── features         # Additional features and modules
│   │   └── secrets.nix  # Secrets management configuration
│   ├── home             # Home Manager user configurations
│   │   ├── common-home.nix # Common home configurations
│   │   └── zsh.nix      # Zsh shell configuration
│   ├── overlays         # Custom overlays for Nix packages
│   │   └── custom-overlay.nix
│   └── system           # System-wide configurations
│       ├── common.nix   # Common system settings
│       ├── desktop.nix  # Desktop environment settings
│       ├── development.nix # Development environment settings
│       └── networking.nix # Networking settings
├── secrets              # Directory for secrets management
│   └── README.md        # Documentation for secrets management
└── tmp                  # Temporary files and directories
```

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

## Configuration

### System Configuration
- Base system configuration is in `modules/system/common.nix`
- Machine-specific configs are in `machines/${MACHINE_NAME}/configuration.nix`
- Features can be enabled/disabled per machine

### Home Manager

- Common user configurations are in `modules/home/common-home.nix`
- ZSH configuration with Powerlevel10k theme in `modules/home/zsh.nix`
- Apply user-level configs via:
  ```bash
  home-manager switch --flake .#${USERNAME}
  ```

### Shell Environment
- ZSH is configured with:
  - Powerlevel10k theme
  - Syntax highlighting
  - Auto-suggestions
  - Auto-completion
  - Common aliases

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

## DevShells

- Development shell environments are defined in `modules/devshells/`
- Enter ephemeral dev environments, e.g.:
  ```bash
  nix develop .#rust
  ```

## Adding a New Machine

1. Create a new directory in `machines/`:
   ```bash
   mkdir -p machines/new-machine
   ```

2. Add configuration files:
   - `configuration.nix`: Machine-specific configuration
   - `hardware-configuration.nix`: Hardware-specific configuration

3. Add the machine to `flake.nix`:
   ```nix
   nixosConfigurations.new-machine = nixpkgs.lib.nixosSystem {
     system = "x86_64-linux";
     modules = [
       ./machines/new-machine/configuration.nix
       home-manager.nixosModules.home-manager
       {
         home-manager.useGlobalPkgs = true;
         home-manager.useUserPackages = true;
         home-manager.users.${username} = import ./modules/home/common-home.nix;
       }
     ];
   };
   ```

## Maintenance

### Updating
```bash
# Update flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

### Garbage Collection
```bash
# Remove old generations
sudo nix-collect-garbage -d

# Remove specific generation
sudo nix-env --delete-generations old
sudo nixos-rebuild boot
```
