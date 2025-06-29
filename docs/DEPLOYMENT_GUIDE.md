# Machine Deployment Guide

## Overview

This guide covers deploying NixOS configurations from this repository to new machines, either during initial installation or on existing systems.

## Deployment Methods

### Method 1: Direct Deployment from Live ISO (Recommended)

This method deploys directly from the NixOS live environment without a basic install.

#### Prerequisites
- NixOS live ISO (25.05 or compatible)
- Network connectivity
- Target machine hardware information

#### Step-by-Step Process

1. **Boot from NixOS Live ISO**
   ```bash
   # Enable flakes in live environment
   export NIX_CONFIG="experimental-features = nix-command flakes"
   
   # Install git for cloning
   nix-shell -p git
   ```

2. **Prepare Disk and Mount**
   ```bash
   # Example for UEFI system with single disk
   parted /dev/sda -- mklabel gpt
   parted /dev/sda -- mkpart ESP fat32 1MB 512MB
   parted /dev/sda -- set 1 esp on
   parted /dev/sda -- mkpart primary 512MB 100%
   
   # Format partitions
   mkfs.fat -F 32 -n BOOT /dev/sda1
   mkfs.ext4 -L nixos /dev/sda2
   
   # Mount filesystems
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount /dev/disk/by-label/BOOT /mnt/boot
   ```

3. **Clone Configuration Repository**
   ```bash
   cd /mnt
   git clone https://github.com/ex1tium/nix-configurations.git
   cd nix-configurations
   ```

4. **Generate Hardware Configuration**
   ```bash
   # Generate hardware config for new machine
   nixos-generate-config --root /mnt --dir ./machines/new-machine
   
   # Review and adjust hardware-configuration.nix
   nano machines/new-machine/hardware-configuration.nix
   ```

5. **Create Machine Configuration**
   ```bash
   # Copy template configuration
   cp machines/elara/configuration.nix machines/new-machine/
   
   # Edit for new machine
   nano machines/new-machine/configuration.nix
   ```

6. **Add Machine to Flake**
   ```bash
   # Edit flake.nix to add new machine
   nano flake.nix
   ```
   
   Add to machines section:
   ```nix
   new-machine = {
     system = "x86_64-linux";
     profile = "developer";  # or "desktop", "server"
     hostname = "new-machine";
     users = [ globalConfig.defaultUser ];
   };
   ```

7. **Deploy Configuration**
   ```bash
   # Install NixOS with flake configuration
   nixos-install --flake .#new-machine --root /mnt
   
   # Set root password when prompted
   # Set user password
   nixos-enter --root /mnt -c 'passwd ex1tium'
   ```

8. **Finalize Installation**
   ```bash
   # Copy configuration to installed system
   cp -r /mnt/nix-configurations /mnt/etc/nixos/
   
   # Reboot into new system
   reboot
   ```

### Method 2: Two-Stage Deployment (Existing Systems)

For existing NixOS systems or when Method 1 isn't suitable.

#### Stage 1: Basic NixOS Installation
```bash
# Standard NixOS installation
nixos-install
reboot

# After reboot, enable flakes
sudo nano /etc/nixos/configuration.nix
# Add: nix.settings.experimental-features = [ "nix-command" "flakes" ];
sudo nixos-rebuild switch
```

#### Stage 2: Apply Flake Configuration
```bash
# Clone repository
git clone https://github.com/ex1tium/nix-configurations.git
cd nix-configurations

# Generate hardware config
sudo nixos-generate-config --dir ./machines/$(hostname)

# Create machine configuration (copy from template)
cp machines/elara/configuration.nix machines/$(hostname)/

# Edit machine configuration
nano machines/$(hostname)/configuration.nix

# Add machine to flake.nix
nano flake.nix

# Apply configuration
sudo nixos-rebuild switch --flake .#$(hostname)
```

## Pre-Configuration Setup

### 1. Define Machine Before Installation

You can prepare machine configurations before physical installation:

```bash
# In your development environment
cd nix-configurations

# Create machine directory
mkdir -p machines/new-workstation

# Create placeholder hardware config
cat > machines/new-workstation/hardware-configuration.nix << 'EOF'
# Hardware configuration for new-workstation
# This will be replaced during installation
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  
  # Placeholder - will be generated during installation
  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };
  
  swapDevices = [ ];
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
EOF

# Create machine configuration
cp machines/elara/configuration.nix machines/new-workstation/
# Edit as needed for the target machine

# Add to flake.nix
# Test configuration
nix flake check
```

### 2. Machine Configuration Templates

Create templates for common machine types:

```bash
# Developer workstation template
machines/templates/developer-workstation.nix

# Server template  
machines/templates/server.nix

# Desktop template
machines/templates/desktop.nix
```

## Network Deployment

### Remote Deployment (Advanced)

For deploying to remote machines:

```bash
# Using nixos-rebuild with target
sudo nixos-rebuild switch --flake .#remote-machine --target-host user@remote-host

# Using deploy-rs (if configured)
deploy .#remote-machine
```

### USB Deployment

For air-gapped or offline deployment:

```bash
# Prepare USB with configuration
nix build .#nixosConfigurations.target-machine.config.system.build.toplevel
cp -r result /media/usb/nixos-config

# On target machine
sudo nixos-rebuild switch --flake /media/usb/nixos-config
```

## Validation and Testing

### Post-Deployment Checklist

```bash
# System health
systemctl --failed
journalctl -p err -b

# Network connectivity
ping google.com

# Desktop environment (if applicable)
echo $XDG_CURRENT_DESKTOP

# Development tools (if applicable)
which code git docker

# Container runtime (if applicable)
docker version
podman version

# User environment
whoami
groups
```

### Automated Validation Script

```bash
#!/usr/bin/env bash
# scripts/validate-deployment.sh

set -euo pipefail

echo "🔍 Validating NixOS deployment..."

# Check system status
echo "📊 System Status:"
systemctl --failed --no-pager || true

# Check profile-specific features
if systemctl is-active --quiet sddm; then
    echo "✅ Desktop environment active"
fi

if command -v docker &> /dev/null; then
    echo "✅ Docker available"
    docker version --format "Docker: {{.Server.Version}}"
fi

if command -v code &> /dev/null; then
    echo "✅ VS Code available"
fi

echo "✅ Deployment validation completed"
```

## Troubleshooting

### Common Issues

1. **Hardware Detection Problems**
   - Re-run `nixos-generate-config`
   - Check kernel modules for specific hardware
   - Verify UEFI vs BIOS boot mode

2. **Network Issues During Installation**
   - Check network connectivity in live environment
   - Configure WiFi if needed: `wpa_supplicant`
   - Use ethernet connection for reliability

3. **Flake Evaluation Errors**
   - Verify flake.nix syntax: `nix flake check`
   - Check machine definition in flake
   - Ensure all imports are correct

4. **Boot Failures**
   - Check bootloader configuration
   - Verify filesystem labels match
   - Review hardware-configuration.nix

### Recovery Procedures

```bash
# Boot from live ISO and mount system
mount /dev/disk/by-label/nixos /mnt
mount /dev/disk/by-label/boot /mnt/boot

# Enter installed system
nixos-enter --root /mnt

# Rollback to previous generation
nixos-rebuild switch --rollback

# Or rebuild with working configuration
cd /etc/nixos/nix-configurations
nixos-rebuild switch --flake .#$(hostname)
```

## Security Considerations

### Initial Setup
- Change default passwords immediately
- Configure SSH keys
- Enable firewall
- Review user permissions

### Secrets Management
- Use SOPS for sensitive configuration
- Avoid committing secrets to git
- Set up proper key management

This deployment guide ensures reliable, repeatable machine provisioning while maintaining the flexibility of your flake-based configuration system.
