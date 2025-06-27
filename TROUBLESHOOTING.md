# Troubleshooting Guide

## Common Issues and Solutions

### 1. Flake Check Failures

#### DevShells System Type Error
**Error**: `'rust' is not a valid system type`
**Solution**: Ensure devShells are properly structured with system support:
```nix
devShells = forAllSystems (system: {
  rust = import ./modules/devshells/rust.nix { 
    pkgs = import nixpkgs { inherit system; }; 
  };
});
```

#### Missing Hardware Configuration
**Error**: `hardware-configuration.nix not found`
**Solution**: Generate hardware config on target machine:
```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix machines/elara/
```

### 2. GPG and Secrets Issues

#### GPG Key Not Found
**Error**: `gpg: decryption failed: No secret key`
**Solution**: 
1. Import your GPG private key:
```bash
gpg --import path/to/private-key.asc
gpg --edit-key your.email@example.com
> trust
> 5
> y
> quit
```

#### Secrets File Missing
**Error**: `secrets.yaml not found`
**Solution**: Either create the file or disable sops validation:
```nix
sops.validateSopsFiles = false;
```

### 3. Home Manager Issues

#### State Version Mismatch
**Error**: `home.stateVersion mismatch`
**Solution**: Ensure consistent state versions:
```nix
# In system config
system.stateVersion = "24.11";
# In home config  
home.stateVersion = "24.11";
```

#### ZSH Plugin Loading Failures
**Error**: Plugin not found or sourcing errors
**Solution**: Use Home Manager's built-in plugin management instead of manual sourcing.

### 4. Build and Deployment Issues

#### Dirty Git Tree Warning
**Warning**: `Git tree is dirty`
**Solution**: This is just a warning. Commit changes or use `--impure` flag if needed.

#### Network Issues During Build
**Error**: `Failed to download`
**Solution**: 
1. Check internet connection
2. Clear Nix cache: `sudo nix-store --gc`
3. Update flake: `nix flake update`

### 5. Development Environment Issues

#### DevShell Not Available
**Error**: `nix develop .#rust` fails
**Solution**: Ensure flake.nix devShells are properly configured and run `nix flake check` first.

## Recovery Procedures

### Rollback System Configuration
```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Rollback to specific generation
sudo /nix/var/nix/profiles/system-<generation>-link/bin/switch-to-configuration switch
```

### Reset Home Manager
```bash
# Remove home-manager generations
home-manager generations | head -5
home-manager remove-generations <generation-ids>
```

### Emergency Boot
If system won't boot:
1. Boot from NixOS installer
2. Mount your system
3. Rollback using chroot:
```bash
sudo nixos-enter --root /mnt
nixos-rebuild switch --rollback
```

## Performance Optimization

### Reduce Build Times
```bash
# Enable binary cache
nix.settings.substituters = [
  "https://cache.nixos.org/"
  "https://nix-community.cachix.org"
];

# Parallel builds
nix.settings.max-jobs = "auto";
nix.settings.cores = 0;
```

### Clean Up Storage
```bash
# Remove old generations
sudo nix-collect-garbage -d

# Optimize store
sudo nix-store --optimize
```

## Getting Help

1. Check NixOS manual: https://nixos.org/manual/
2. Home Manager manual: https://nix-community.github.io/home-manager/
3. Search existing issues: https://github.com/NixOS/nixpkgs/issues
4. Ask on NixOS Discourse: https://discourse.nixos.org/
