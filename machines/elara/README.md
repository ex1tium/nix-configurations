# Elara Machine Configuration

This directory contains the configuration for the `elara` machine (test VM).

## Hardware Configuration

**No default `hardware-configuration.nix` is provided** - this file is generated fresh during each installation to ensure:

- ✅ **Correct UUIDs** for the actual filesystem layout
- ✅ **Proper hardware detection** for current system
- ✅ **Accurate partitioning** for chosen installation mode
- ✅ **Correct encryption setup** when LUKS is used

### Installation Process

1. **Fresh Generation**: `nixos-generate-config` creates hardware config for current hardware
2. **Preview & Confirm**: Installer shows the config and asks for confirmation  
3. **Installation**: Fresh config is used for the actual installation
4. **Optional Backup**: User can choose to commit the generated config back to repo

### Manual Hardware Config

If you need to manually create a hardware configuration:

```bash
# Generate for current system
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix

# Or copy from an existing installation
cp /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
```

### Why This Approach?

- **VM vs Real Hardware**: Same config works on different hardware
- **Fresh Installs**: Each installation gets correct UUIDs and settings
- **No Stale Configs**: Prevents using outdated hardware configurations
- **Flexibility**: Supports fresh/dual-boot/manual installation modes
