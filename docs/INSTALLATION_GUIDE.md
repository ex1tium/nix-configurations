# NixOS Installation Guide

This guide covers installing NixOS using the automated installation script that supports various scenarios including dual-boot setups.

## 🚀 Quick Start

### Option 1: Automated Script (Recommended)
```bash
# Boot from NixOS ISO, then run:
curl -L https://raw.githubusercontent.com/ex1tium/nix-configurations/main/scripts/install-elara.sh | bash
```

### Option 2: Manual Download
```bash
# Boot from NixOS ISO
nix-shell -p git
git clone https://github.com/ex1tium/nix-configurations.git
cd nix-configurations
./scripts/install-elara.sh
```

## 📋 Supported Installation Scenarios

### 1. Fresh Installation (VM or Dedicated Disk)
- **Use Case**: New VM, empty disk, or replacing existing OS
- **Safety**: ⚠️ **ERASES ALL DATA** on selected disk
- **Requirements**: Any disk with sufficient space (20GB minimum, 50GB recommended)

### 2. Dual-Boot with Windows
- **Use Case**: Keep existing Windows installation
- **Safety**: ✅ **100% SAFE** - Only uses free space
- **Requirements**: 
  - Existing Windows with EFI boot
  - At least 20GB free space
  - GPT partition table

### 3. Dual-Boot with Linux
- **Use Case**: Keep existing Linux distribution
- **Safety**: ✅ **100% SAFE** - Only uses free space  
- **Requirements**:
  - Existing Linux with EFI boot
  - At least 20GB free space
  - GPT partition table

### 4. Multi-Disk Setup
- **Use Case**: Windows on one disk, NixOS on another
- **Safety**: ✅ **100% SAFE** - No risk to existing OS
- **Requirements**: Separate disk for NixOS

## 🔍 What the Script Does

### 1. Disk Detection and Analysis
```
💽 Available storage devices:
==================================
NAME        SIZE TYPE FSTYPE      MOUNTPOINT MODEL
sda         500G disk                        Samsung SSD
├─sda1      100M part vfat        /boot/efi  
├─sda2       16M part                        
├─sda3      200G part ntfs                   Windows
└─sda4      299G part                        (Free Space)
sdb          1T disk                         WD Blue HDD
```

### 2. OS Detection
The script automatically detects:
- **Windows**: NTFS partitions, bootmgr, Windows folders
- **Linux**: ext4/btrfs partitions, /boot and /etc directories  
- **macOS**: HFS+/APFS partitions, System/Library folders
- **Free Space**: Unpartitioned areas suitable for NixOS

### 3. Safe Partitioning
- **Fresh Install**: Creates new GPT table with EFI + root partitions
- **Dual-Boot**: Uses existing EFI partition, creates new root partition in free space
- **Manual**: Allows custom partitioning for advanced users

## 🛡️ Safety Features

### Dual-Boot Protection
- ✅ **Never touches existing OS partitions**
- ✅ **Reuses existing EFI partition safely**
- ✅ **Only partitions free/unallocated space**
- ✅ **Validates sufficient space before proceeding**
- ✅ **Preserves existing bootloader entries**

### Confirmation Steps
- ✅ **Shows detailed disk analysis before proceeding**
- ✅ **Requires explicit confirmation for destructive operations**
- ✅ **Validates all inputs and requirements**
- ✅ **Provides clear warnings about data loss risks**

## 📏 Space Requirements

| Installation Type | Minimum | Recommended | Notes |
|------------------|---------|-------------|-------|
| Basic Desktop    | 20GB    | 50GB        | Includes KDE Plasma |
| Development      | 30GB    | 100GB       | With dev tools |
| Full Featured    | 50GB    | 200GB       | All packages |

## 🔧 Manual Partitioning (Advanced)

If you choose manual partitioning, create:

### Required Partitions
1. **EFI System Partition** (if not exists)
   - Size: 512MB
   - Type: EFI System (EF00)
   - Format: FAT32
   - Mount: `/mnt/boot`

2. **Root Partition**
   - Size: 20GB minimum
   - Type: Linux filesystem (8300)
   - Format: ext4
   - Mount: `/mnt`

### Example Manual Setup
```bash
# Create partitions with fdisk/parted
sudo parted /dev/sda mkpart primary ext4 100GB 150GB

# Format partitions
sudo mkfs.ext4 -L nixos /dev/sda4

# Mount filesystems
sudo mount /dev/sda4 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/sda1 /mnt/boot  # Existing EFI partition
```

## 🎯 Post-Installation

The installer now handles password setup automatically, but here's what happens:

### **Password Setup (Automated)**

The installer will prompt you to:

1. **Set User Password** (Recommended)
   ```
   🔑 Setting up user account password...
   Set password for user 'ex1tium' now? [Y/n]: Y
   ```

2. **Set Root Password** (Optional)
   ```
   Set emergency root password? (optional but recommended) [y/N]: y
   ```

### **Manual Password Setup** (If Skipped)

If you skipped password setup during installation:

**From Installer Environment:**
```bash
# Set user password
sudo chroot /mnt passwd ex1tium

# Set root password (optional)
sudo chroot /mnt passwd root
```

**After Reboot (Recovery Mode):**
```bash
# Boot into recovery mode, then:
passwd ex1tium  # Set user password
passwd root     # Set root password (optional)
```

### **System Updates** (Optional)
```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake .#elara
```

### **Verify Dual-Boot** (If applicable)
- Reboot and check GRUB menu
- Verify both operating systems boot correctly

## 🔐 **NixOS Security Model**

Understanding how user accounts work in your new NixOS system:

### **User Account Structure**
- **Primary User**: `ex1tium` (admin privileges via sudo)
- **Root Account**: Disabled for direct login (security best practice)
- **Sudo Access**: Available to users in `wheel` group

### **Login Methods**
```bash
# ✅ Correct way to login
ssh ex1tium@hostname
# or local login as ex1tium

# ❌ Root login disabled
ssh root@hostname  # This will fail

# ✅ Become root when needed
sudo su -
# or run commands with sudo
```

### **Password Policy**
- **User Password**: Required for login and sudo operations
- **Root Password**: Optional, only for emergency recovery
- **SSH Keys**: Can be configured for passwordless login (advanced)

### **Security Features**
- ✅ **Root login disabled** (modern security practice)
- ✅ **Sudo-only privilege escalation**
- ✅ **Wheel group membership** required for admin access
- ✅ **SSH root login blocked** by default

## ❓ Troubleshooting

### Common Issues

**"No EFI partition found"**
- Your system may use legacy BIOS
- Convert to UEFI or use legacy installation method

**"Insufficient free space"**
- Use disk management tools to shrink existing partitions
- Consider using a separate disk

**"Installation failed"**
- Check internet connection
- Verify hardware compatibility
- Try manual partitioning mode

### Getting Help
- Check logs: `journalctl -xe`
- NixOS manual: `nixos-help`
- Community: [NixOS Discourse](https://discourse.nixos.org/)

## 🎉 What You Get

After installation, your system includes:
- ✅ **Modern NixOS 25.05** with latest packages
- ✅ **KDE Plasma 6** desktop environment
- ✅ **Development tools** (VS Code, Git, modern CLI)
- ✅ **Virtualization support** (Docker, libvirt)
- ✅ **Finnish locale** with English interface
- ✅ **ZSH + Powerlevel10k** shell setup
- ✅ **Proper dual-boot** (if selected)
