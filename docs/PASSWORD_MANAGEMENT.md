# NixOS Password Management Guide

Quick reference for managing passwords in your NixOS installation.

## 🔑 **Password Setup During Installation**

The installer script automatically handles password setup:

### **Interactive Setup**
```bash
🔑 Setting up user account password...
    Detected primary user: ex1tium
    The primary user 'ex1tium' needs a password for login.

Set password for user 'ex1tium' now? [Y/n]: Y
Please enter a secure password for user 'ex1tium':
✅ Password set successfully for user 'ex1tium'

Set emergency root password? (optional but recommended) [y/N]: y
Setting emergency root password (for recovery situations):
✅ Root password set (use only for emergency recovery)
```

## 🛠️ **Manual Password Management**

### **Setting Passwords After Installation**

**From the installer environment (before reboot):**
```bash
# Set user password
sudo chroot /mnt passwd ex1tium

# Set root password (optional)
sudo chroot /mnt passwd root
```

**After system is running:**
```bash
# Change your own password
passwd

# Change another user's password (requires sudo)
sudo passwd ex1tium

# Set root password (emergency access only)
sudo passwd root
```

### **Password Recovery Scenarios**

**Scenario 1: Forgot user password, root password set**
```bash
# Boot into recovery mode or single-user mode
# Login as root, then:
passwd ex1tium
```

**Scenario 2: Forgot user password, no root password**
```bash
# Boot from NixOS ISO
# Mount your system
sudo mount /dev/sdXY /mnt  # Your root partition
sudo mount /dev/sdXZ /mnt/boot  # Your EFI partition

# Set password
sudo chroot /mnt passwd ex1tium
```

**Scenario 3: Complete password reset**
```bash
# Boot from NixOS ISO, mount system, then:
sudo chroot /mnt passwd ex1tium  # User password
sudo chroot /mnt passwd root     # Root password
```

## 🔐 **Security Best Practices**

### **Password Strength**
- ✅ **Minimum 12 characters**
- ✅ **Mix of letters, numbers, symbols**
- ✅ **Unique password** (not used elsewhere)
- ✅ **Consider using a password manager**

### **Account Security**
- ✅ **User account**: Strong password required
- ⚠️ **Root account**: Emergency access only
- 🔒 **SSH keys**: Preferred over passwords for remote access

### **NixOS Security Model**
```
┌─────────────────┐
│   User Login    │ ← Strong password required
│   (ex1tium)     │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│   Sudo Access   │ ← Requires user password
│   (wheel group) │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│  Root Privileges│ ← No direct login
│     (disabled)  │
└─────────────────┘
```

## 🚨 **Emergency Access**

### **If Locked Out Completely**

1. **Boot from NixOS ISO**
2. **Mount your system:**
   ```bash
   # Find your partitions
   lsblk
   
   # Mount root partition
   sudo mount /dev/sdXY /mnt
   
   # Mount EFI partition
   sudo mount /dev/sdXZ /mnt/boot
   ```

3. **Reset passwords:**
   ```bash
   # Enter your system
   sudo chroot /mnt
   
   # Reset user password
   passwd ex1tium
   
   # Set root password for future emergencies
   passwd root
   
   # Exit and reboot
   exit
   sudo reboot
   ```

### **Single User Mode** (Alternative)
```bash
# At GRUB menu, edit the kernel line and add:
systemd.unit=rescue.target

# This boots into single-user mode where you can reset passwords
```

## 📋 **Quick Commands Reference**

| Task | Command |
|------|---------|
| Change your password | `passwd` |
| Change user password (as admin) | `sudo passwd username` |
| Set root password | `sudo passwd root` |
| Disable root password | `sudo passwd -l root` |
| Check password status | `sudo passwd -S username` |
| Force password change on next login | `sudo passwd -e username` |

## 🔧 **Advanced: SSH Key Setup**

For passwordless login (more secure than passwords):

```bash
# Generate SSH key pair (on your client machine)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy public key to NixOS system
ssh-copy-id ex1tium@your-nixos-machine

# Or manually add to authorized_keys
cat ~/.ssh/id_ed25519.pub | ssh ex1tium@your-nixos-machine 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
```

## ⚠️ **Important Notes**

- **Root login is disabled by default** in your NixOS configuration
- **Always set a user password** - the system is unusable without it
- **Root password is optional** but recommended for emergencies
- **Use sudo** for administrative tasks, not direct root login
- **SSH root login is blocked** for security (use user account + sudo)

## 🆘 **Getting Help**

If you're still locked out:
1. **Boot from NixOS ISO** (always works)
2. **Mount and chroot** into your system
3. **Reset passwords** as needed
4. **Consider setting up SSH keys** for future convenience

The NixOS community is helpful for password recovery questions:
- [NixOS Discourse](https://discourse.nixos.org/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- IRC: #nixos on Libera.Chat
