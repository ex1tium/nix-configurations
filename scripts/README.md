# NixOS Installation Utilities

This directory contains comprehensive installation utilities for deploying NixOS configurations from this repository.

## 🚀 Quick Start

### Comprehensive Machine Installer (Recommended)

```bash
# Download and run the comprehensive installer
curl -L https://raw.githubusercontent.com/ex1tium/nix-configurations/main/scripts/install_machine.sh | bash
```

Or clone the repository first:

```bash
git clone https://github.com/ex1tium/nix-configurations.git
cd nix-configurations
./scripts/install_machine.sh
```

### Legacy Elara Installer

```bash
# For direct Elara machine installation
./scripts/install-elara.sh [--fs btrfs|ext4|xfs] [--encrypt] [--branch main]
```

## 📋 Installation Scripts

### `install_machine.sh` - Comprehensive Installation Utility

**Features:**
- 🎯 **Interactive machine selection** from available configurations
- 🗂️ **Multiple filesystem support** (BTRFS/ext4/XFS) with explanations
- 🔒 **LUKS2 encryption options** with security recommendations
- 📸 **BTRFS snapshots integration** with automatic configuration
- 🔧 **Enhanced error handling** with recovery mechanisms
- 📊 **Progress indicators** and comprehensive logging
- 👤 **Dynamic user detection** from flake configuration
- ✅ **Pre/post installation validation** with build testing

**Usage:**
```bash
./scripts/install_machine.sh
```

The script will guide you through:
1. System validation and dependency bootstrap
2. Repository setup and machine discovery
3. Interactive machine selection menu
4. Filesystem configuration (BTRFS/ext4/XFS)
5. Encryption setup (LUKS2 optional)
6. Disk selection with safety warnings
7. User configuration with validation
8. Pre-installation validation and build testing
9. Installation execution with progress tracking

### `install-elara.sh` - Legacy Elara Installer

**Features:**
- 🎯 **Hardcoded for Elara machine** configuration
- 🗂️ **BTRFS with optimal subvolume layout** (@root, @home, @nix, @snapshots)
- 🔒 **Optional LUKS2 encryption**
- 📸 **Automatic BTRFS snapshots** configuration
- 🔧 **Robust error handling** and logging
- 🛡️ **Dual-boot safety** with ESP backup

**Command Line Options:**
- `--fs btrfs|ext4|xfs` - Filesystem type (default: btrfs)
- `--encrypt` - Enable LUKS2 encryption
- `--branch <name>` - Git branch to use (default: main)

## 🏗️ Architecture Compatibility

Both installers are designed to work with our layered NixOS architecture:

```
Machine → Profile → Features → Core
```

- **Machine**: Hardware-specific configuration and overrides
- **Profile**: Role-based configuration (desktop/developer/server)
- **Features**: Modular functionality (desktop, development, virtualization, etc.)
- **Core**: Foundation services and system basics

## 🔧 System Requirements

### Minimum Requirements
- **Memory**: 2GB RAM (4GB+ recommended)
- **Storage**: 20GB free space (50GB+ recommended)
- **Network**: Internet connection for package downloads
- **Environment**: NixOS live ISO or existing NixOS system

### Supported Hardware
- **Architecture**: x86_64-linux
- **Storage**: NVMe, SATA, virtio-blk devices
- **Boot**: UEFI systems (legacy BIOS not supported)
- **Virtualization**: VMware, VirtualBox, QEMU/KVM, Hyper-V

## 📸 BTRFS Best Practices

When using BTRFS (recommended), the installer implements optimal practices:

### Subvolume Layout
```
@root      - System files (/)
@home      - User data (/home)
@nix       - Nix store (/nix)
@snapshots - Snapshot storage (/.snapshots)
```

### Modern BTRFS Defaults
- **DUP metadata**: Better safety for single-device setups
- **no-holes**: Improved performance and space efficiency
- **free-space-tree**: Faster mounts and allocations
- **zstd compression**: Optimal compression for modern systems

### Snapshot Configuration
- **Root snapshots**: 10 hourly, 7 daily, 4 weekly, 2 monthly
- **Home snapshots**: 24 hourly, 7 daily, 4 weekly, 3 monthly, 1 yearly
- **Automatic cleanup**: Timeline-based retention policies
- **User permissions**: Configured for detected primary user

## 🛡️ Security Features

### Encryption (Optional)
- **LUKS2**: Modern encryption with Argon2 key derivation
- **Full disk encryption**: Protects all data at rest
- **Secure boot compatibility**: Works with UEFI secure boot

### System Hardening
- **Minimal attack surface**: Only essential services enabled
- **User isolation**: Proper user/group separation
- **Firewall**: Enabled by default with minimal open ports
- **Sudo configuration**: Wheel group with password requirement

## 🔍 Troubleshooting

### Common Issues

**Installation fails with "No internet connection"**
```bash
# Check network connectivity
ping -c 3 8.8.8.8

# Restart network manager (if available)
sudo systemctl restart NetworkManager
```

**Build validation fails**
```bash
# Check flake syntax
nix flake check

# View detailed error logs
cat /tmp/flake_check.log
cat /tmp/build_test.log
```

**Disk not detected**
```bash
# List available disks
lsblk -d

# Check for hardware issues
dmesg | grep -i error
```

### Recovery Options

The comprehensive installer provides built-in recovery mechanisms:

1. **Error details**: View detailed error information and logs
2. **Retry from checkpoint**: Attempt to continue from failure point
3. **Clean up and exit**: Safely unmount and clean temporary files

### Log Files

Installation logs are stored in `/tmp/`:
- `nixos-install-YYYYMMDD-HHMMSS.log` - Main installation log
- `nixos-install-detailed.log` - Detailed installation output
- `flake_check.log` - Flake validation output
- `build_test.log` - Configuration build test output

## 🚀 Future Roadmap

### Planned Features (Not Yet Implemented)
- **Machine template creation wizard** for new configurations
- **Backup/restore functionality** for existing installations
- **Multi-boot setup assistance** for complex scenarios
- **Network installation support** for remote deployments
- **Custom partition layouts** beyond standard configurations

### Contributing

To contribute to the installation utilities:

1. Test changes in a VM environment first
2. Ensure compatibility with all supported machine profiles
3. Update documentation for any new features
4. Follow the existing error handling patterns
5. Add appropriate logging for debugging

## 📚 Related Documentation

- [Architecture Documentation](../docs/ARCHITECTURE.md)
- [Machine Configuration Guide](../machines/README.md)
- [BTRFS Snapshots Guide](../modules/features/btrfs-snapshots.nix)
- [Security Configuration](../modules/nixos/security.nix)

---

**⚠️ Important**: Always test installation scripts in a virtual machine before using on production hardware. The installation process will destroy all data on the target disk.
