# Magos Machine Configuration

Development machine with dual-boot Windows 11 (AtlasOS) + NixOS on 128 GB UFS/eUFS storage.
Uses the developer profile with full development tools, Docker, and libvirt/KVM support.

## Hardware Specifications

- **Storage**: 128 GB UFS/eUFS device (`/dev/sdb`)
- **CPU**: Intel (with microcode updates)
- **GPU**: Auto-detected (supports Intel, AMD, NVIDIA)
- **RAM**: 8 GB (zram + swap configured)
- **Display**: KDE Plasma 6 (primary), XFCE (alternative)

## Partition Layout

| Device | Size | Type | Purpose |
|--------|------|------|---------|
| sdb1 | 260 MiB | vfat | EFI System Partition (shared with Windows) |
| sdb2 | 16 MiB | MSR | Microsoft Reserved |
| sdb3 | 64 GiB | BitLocker | Windows C: drive |
| sdb4 | 4 GiB | BitLocker | Shared data (to be exFAT) |
| sdb5 | 787 MiB | NTFS | Windows Recovery |
| sdb6 | 46 GiB | Btrfs | NixOS root |
| sdb7 | ~4.2 GiB | swap | Linux swap |

## Btrfs Subvolume Structure

On `sdb6` (nixos-root):

- `@` → `/` (root filesystem)
- `@nix` → `/nix` (Nix store, NOCOW for reduced write amplification)
- `@home` → `/home` (user home directories)
- `@log` → `/var/log` (system logs)
- `@cache` → `/var/cache` (package cache)
- `@snapshots` → `/.snapshots` (Snapper snapshots)

## Configuration Features

### Development Tools
- **Languages**: Node.js, Go, Python, Rust, Nix, Java
- **Build Tools**: gcc, make, cmake, cargo, npm, pip, etc.
- **Version Control**: Git, GitHub CLI
- **Editors**: VS Code with cyberdeck theme, nano

### Virtualization & Containers
- **Docker**: Full Docker support with docker-compose
- **libvirt/KVM**: Virtual machine support
- **LXC/LXD**: Lightweight container support
- **Kubernetes**: kubectl, helm, k9s

### Desktop Environment
- **Primary**: KDE Plasma 6 with Wayland
- **Alternative**: XFCE for low-spec scenarios
- **Display Server**: Wayland (preferred), X11 fallback

### Storage & Snapshots
- **Filesystem**: Btrfs with zstd compression
- **Snapshots**: Snapper configured for hourly/daily/weekly/monthly timelines
- **Maintenance**: Weekly fstrim and btrfs scrub
- **Swap**: zram (50% of RAM) + 4 GiB disk swap

### Power Management
- **TLP**: Battery-friendly CPU scaling and WiFi power saving
- **Hibernation**: Disabled (prevents NTFS dirty state in dual-boot)
- **Charging**: Battery thresholds (20-80%) to extend battery life

### Networking
- **NetworkManager**: For easy WiFi/Ethernet management
- **SSH**: Enabled for remote management
- **Firewall**: Enabled with SSH access

### Localization
- **Timezone**: Europe/Helsinki
- **Locale**: en_US.UTF-8 (UI), fi_FI (formats)
- **Keyboard**: Finnish (fi)

## Installation Instructions

### Prerequisites
- Live NixOS USB with flakes support
- Partitions already created (see handover document)
- Btrfs subvolumes already created
- **Git Access**: SSH key or PAT configured (see MAGOS_GIT_SETUP.md)

### Installation Steps

1. **Set up git access** (see MAGOS_GIT_SETUP.md for detailed instructions):
   ```bash
   # Option A: SSH (recommended)
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   # Copy your SSH key to ~/.ssh/id_ed25519
   chmod 600 ~/.ssh/id_ed25519
   ssh-keyscan github.com >> ~/.ssh/known_hosts

   # Option B: HTTPS with PAT
   git config --global credential.helper store
   ```

2. **Clone the repository**:
   ```bash
   cd /tmp
   git clone git@github.com:ex1tium/nix-configurations.git
   cd nix-configurations
   ```

3. **Mount filesystems** (if not already done):
   ```bash
   mount -o subvol=@,compress=zstd,ssd,noatime,space_cache=v2,autodefrag \
     /dev/disk/by-label/nixos-root /mnt
   mkdir -p /mnt/{nix,home,var/log,var/cache,.snapshots,boot/efi}
   mount -o subvol=@nix,ssd,noatime /dev/disk/by-label/nixos-root /mnt/nix
   mount -o subvol=@home,compress=zstd,ssd,noatime /dev/disk/by-label/nixos-root /mnt/home
   mount -o subvol=@log,compress=zstd,ssd,noatime /dev/disk/by-label/nixos-root /mnt/var/log
   mount -o subvol=@cache,compress=zstd,ssd,noatime /dev/disk/by-label/nixos-root /mnt/var/cache
   mount -o subvol=@snapshots,compress=zstd,ssd,noatime /dev/disk/by-label/nixos-root /mnt/.snapshots
   mount /dev/sdb1 /mnt/boot/efi
   swapon /dev/disk/by-label/nixos-swap
   ```

4. **Generate hardware configuration**:
   ```bash
   nixos-generate-config --root /mnt
   ```

5. **Install NixOS** (using local cloned repository):
   ```bash
   nixos-install --flake /tmp/nix-configurations#magos
   ```

6. **Reboot and configure**:
   ```bash
   reboot
   ```

## Post-Installation

### First Boot
- System will boot into NixOS with KDE Plasma 6
- Configure user password if not set during installation
- Verify Snapper snapshots: `sudo snapper list`
- Check zram: `zramctl`

### Windows Shared Partition
- Reboot into Windows
- Reformat `sdb4` from BitLocker to exFAT (label: "Shared")
- Disable hibernation in Windows (prevents NTFS dirty state)

### Verify Configuration
```bash
# Check Btrfs subvolumes
btrfs subvolume list /

# Check snapshots
sudo snapper list

# Check zram swap
zramctl

# Check power management
tlp-stat

# Check Snapper timelines
sudo snapper list -t
```

## Maintenance

### Regular Tasks
- **Weekly**: Btrfs scrub, fstrim
- **Hourly**: Snapper snapshots (automatic)
- **Monthly**: Review and clean old snapshots

### Snapshot Management
```bash
# List snapshots
sudo snapper list

# Create manual snapshot
sudo snapper create -d "manual backup"

# Rollback to snapshot
sudo snapper rollback <snapshot-number>

# Delete old snapshots
sudo snapper delete <snapshot-number>
```

### Troubleshooting

**Dual-boot issues**: Ensure Windows hibernation is disabled
**Btrfs errors**: Run `sudo btrfs filesystem show` and `sudo btrfs scrub start /`
**Snapshot space**: Check with `sudo snapper list` and delete old snapshots if needed

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Btrfs Wiki](https://btrfs.readthedocs.io/)
- [Snapper Documentation](https://snapper.io/)
- [TLP Power Management](https://linrunner.de/tlp/)

