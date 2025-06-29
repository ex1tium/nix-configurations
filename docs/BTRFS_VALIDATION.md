# BTRFS Setup Validation Against NixOS Wiki

This document validates our BTRFS implementation against the official [NixOS Wiki BTRFS guidelines](https://nixos.wiki/wiki/Btrfs).

## ✅ Compliance Summary

Our installer now **fully complies** with NixOS Wiki BTRFS recommendations:

### **Partitioning** ✅
- **EFI Boot Partition**: 550MB FAT32 with ESP flag
- **BTRFS Root Partition**: Remainder of disk
- **Partition Table**: GPT (modern standard)

### **Subvolume Structure** ✅
```
/dev/sdX2 (BTRFS filesystem)
├── root      → mounted at /
├── home      → mounted at /home  
├── nix       → mounted at /nix
└── snapshots → mounted at /.snapshots
```

**Naming Convention**: Uses NixOS standard names (`root`, `home`, `nix`, `snapshots`) without `@` prefix.

### **Mount Options** ✅
- **Root**: `subvol=root,compress=zstd`
- **Home**: `subvol=home,compress=zstd`
- **Nix**: `subvol=nix,compress=zstd,noatime` (performance optimization)
- **Snapshots**: `subvol=snapshots,compress=zstd`

### **Hardware Configuration** ✅
```nix
# Proper BTRFS support
boot.supportedFilesystems = [ "btrfs" ];
boot.initrd.supportedFilesystems = [ "btrfs" ];

# Correct filesystem definitions
fileSystems."/" = {
  device = "/dev/disk/by-uuid/UUID";
  fsType = "btrfs";
  options = [ "subvol=root" "compress=zstd" ];
};

fileSystems."/home" = {
  device = "/dev/disk/by-uuid/UUID";
  fsType = "btrfs";
  options = [ "subvol=home" "compress=zstd" ];
};

fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/UUID";
  fsType = "btrfs";
  options = [ "subvol=nix" "compress=zstd" "noatime" ];
};

fileSystems."/.snapshots" = {
  device = "/dev/disk/by-uuid/UUID";
  fsType = "btrfs";
  options = [ "subvol=snapshots" "compress=zstd" ];
};
```

## 🔧 Key Improvements Made

### **1. Subvolume Naming** 
- **Before**: `@root`, `@home`, `@nix`, `@snapshots` (Ubuntu/openSUSE style)
- **After**: `root`, `home`, `nix`, `snapshots` (NixOS standard)

### **2. Mount Options**
- **Added**: `noatime` for `/nix` (performance optimization per Wiki)
- **Consistent**: `compress=zstd` for all subvolumes

### **3. Boot Configuration**
- **Added**: `boot.supportedFilesystems = [ "btrfs" ];` (system-wide support)
- **Enhanced**: `boot.initrd.supportedFilesystems = [ "btrfs" ];` (early boot support)

### **4. UUID Detection**
- **Fixed**: Use `blkid` on actual block device instead of mount UUID
- **Robust**: Handle subvolume mount sources correctly

## 📋 Installation Process Validation

Our installer follows the exact NixOS Wiki process:

1. **Partition Disk** → GPT with EFI + BTRFS partitions ✅
2. **Format Partitions** → FAT32 boot + BTRFS root ✅  
3. **Create Subvolumes** → Standard NixOS naming ✅
4. **Mount Subvolumes** → Correct options and structure ✅
5. **Generate Hardware Config** → Proper BTRFS configuration ✅
6. **Install NixOS** → Standard `nixos-install` process ✅

## 🎯 Differences from Wiki Example

The only intentional differences are **improvements**:

1. **Additional Snapshots Subvolume**: We create a dedicated snapshots subvolume for better snapshot management
2. **Enhanced Error Handling**: More robust error checking and recovery
3. **Automated Validation**: Automatic hardware config validation and fixing
4. **Modern Defaults**: Uses latest BTRFS features and optimizations

## 🚀 Expected Results

With these changes, the installation should:

- ✅ **Boot successfully** with proper BTRFS root filesystem
- ✅ **Mount all subvolumes** correctly at boot time
- ✅ **Support snapshots** via the dedicated snapshots subvolume
- ✅ **Perform optimally** with compression and noatime options
- ✅ **Be maintainable** following NixOS conventions

## 🔍 Validation Commands

To verify a successful installation:

```bash
# Check subvolume structure
sudo btrfs subvolume list /

# Verify mount options
findmnt -t btrfs

# Check hardware configuration
cat /etc/nixos/hardware-configuration.nix | grep -A 3 "fileSystems"

# Verify BTRFS support
grep -r "supportedFilesystems.*btrfs" /etc/nixos/
```

## 📚 References

- [NixOS Wiki - BTRFS](https://nixos.wiki/wiki/Btrfs)
- [BTRFS Documentation](https://btrfs.readthedocs.io/)
- [NixOS Manual - File Systems](https://nixos.org/manual/nixos/stable/index.html#sec-file-systems)
