# Manual Boot Repair Guide

If the automated repair script fails, follow these manual steps:

## 1. Boot from NixOS Live Environment

Boot from your NixOS installation media.

## 2. Identify Your Partitions

```bash
# List all partitions
lsblk

# Find BTRFS partitions
lsblk -f | grep btrfs

# Find EFI System Partition
lsblk -f | grep vfat
```

## 3. Mount the Filesystem

Replace `/dev/sdXY` with your actual partition:

```bash
# Create mount point
sudo mkdir -p /mnt

# Try to mount with @root subvolume
sudo mount -o subvol=@root,compress=zstd /dev/sdXY /mnt

# If that fails, mount without subvolume first
sudo mount /dev/sdXY /mnt

# Check if subvolumes exist
sudo btrfs subvolume list /mnt

# If @root subvolume doesn't exist, create it
sudo btrfs subvolume create /mnt/@root
sudo btrfs subvolume create /mnt/@home  
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@snapshots

# Unmount and remount with @root
sudo umount /mnt
sudo mount -o subvol=@root,compress=zstd /dev/sdXY /mnt
```

## 4. Mount Other Subvolumes and ESP

```bash
# Create directories
sudo mkdir -p /mnt/{home,nix,.snapshots,boot}

# Mount subvolumes
sudo mount -o subvol=@home,compress=zstd /dev/sdXY /mnt/home
sudo mount -o subvol=@nix,compress=zstd /dev/sdXY /mnt/nix  
sudo mount -o subvol=@snapshots,compress=zstd /dev/sdXY /mnt/.snapshots

# Mount ESP (replace /dev/sdXZ with your ESP partition)
sudo mount /dev/sdXZ /mnt/boot
```

## 5. Fix Hardware Configuration

```bash
# Check current hardware config
sudo cat /mnt/etc/nixos/hardware-configuration.nix

# If it's missing BTRFS subvolume options, regenerate it
sudo nixos-generate-config --root /mnt

# Or manually edit it to include subvolume options:
sudo nano /mnt/etc/nixos/hardware-configuration.nix
```

The hardware config should look like this:

```nix
fileSystems."/" = {
  device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
  fsType = "btrfs";
  options = [ "subvol=@root" "compress=zstd" ];
};

fileSystems."/home" = {
  device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
  fsType = "btrfs";
  options = [ "subvol=@home" "compress=zstd" ];
};

fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
  fsType = "btrfs";
  options = [ "subvol=@nix" "compress=zstd" ];
};

fileSystems."/.snapshots" = {
  device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
  fsType = "btrfs";
  options = [ "subvol=@snapshots" "compress=zstd" ];
};
```

## 6. Reinstall Bootloader

```bash
# Bind mount necessary filesystems
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc  
sudo mount --bind /sys /mnt/sys

# Chroot and rebuild
sudo chroot /mnt nixos-rebuild boot

# Or if that fails, try switch
sudo chroot /mnt nixos-rebuild switch
```

## 7. Cleanup and Reboot

```bash
# Unmount everything
sudo umount /mnt/dev /mnt/proc /mnt/sys
sudo umount -R /mnt

# Reboot
sudo reboot
```

## Common Issues and Solutions

### Issue: "subvolume @root not found"
**Solution**: The subvolumes weren't created properly. Follow step 3 to create them.

### Issue: "mount: wrong fs type, bad option, bad superblock"
**Solution**: The partition might be corrupted. Check with `fsck.btrfs /dev/sdXY`.

### Issue: Hardware config still wrong after regeneration
**Solution**: Manually edit the hardware-configuration.nix file to include the correct subvolume options.

### Issue: Bootloader installation fails
**Solution**: Make sure all bind mounts are in place and try `nixos-install --root /mnt` instead.

## Prevention for Future Installations

The installation script has been updated to:
1. Add better error checking for subvolume creation
2. Verify mounts before proceeding
3. Add sync operations to ensure data is written
4. Improve timing between operations

This should prevent similar issues in future installations.
