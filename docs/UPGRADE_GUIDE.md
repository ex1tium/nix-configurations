# NixOS Upgrade Guide

## Version Management Strategy

### Current Configuration
- **NixOS Version**: 25.05 (unstable)
- **Kernel Strategy**: 
  - Developer machines: `latest` (for hardware support)
  - Server machines: `stable` (for reliability)
- **Update Philosophy**: Manual updates with testing

## Upgrade Workflows

### 1. Regular Flake Updates (Weekly)

```bash
# Update flake inputs
nix flake update

# Check for issues
nix flake check

# Test build without switching
sudo nixos-rebuild build --flake .#$(hostname)

# Apply if successful
sudo nixos-rebuild switch --flake .#$(hostname)
```

### 2. NixOS Version Upgrades (Quarterly)

#### Preparation
```bash
# Backup current generation
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo cp -r /etc/nixos /etc/nixos.backup.$(date +%Y%m%d)

# Update to new NixOS version
git checkout -b upgrade-nixos-$(date +%Y%m%d)
```

#### Update Process
1. **Update flake.nix inputs**:
   ```nix
   # Change in flake.nix
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-XX.XX";
   ```

2. **Update state version** (only for major releases):
   ```nix
   # In globalConfig
   defaultStateVersion = "XX.XX";
   ```

3. **Test incrementally**:
   ```bash
   # Test on development machine first
   sudo nixos-rebuild build --flake .#elara
   sudo nixos-rebuild switch --flake .#elara
   
   # Test other profiles
   nix build .#nixosConfigurations.test-desktop.config.system.build.toplevel
   ```

#### Rollback if Needed
```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Or specific generation
sudo /nix/var/nix/profiles/system-XX-link/bin/switch-to-configuration switch
```

### 3. Kernel Update Strategy

#### Developer Machines (Latest Kernel)
- **Rationale**: Better hardware support, latest features
- **Risk**: Potential instability
- **Mitigation**: Easy rollback, development environment tolerance

```nix
# In machine configuration
mySystem.hardware.kernel = "latest";
```

#### Server Machines (Stable Kernel)
- **Rationale**: Maximum stability and reliability
- **Risk**: Missing hardware support for newer systems
- **Mitigation**: LTS kernel with security backports

```nix
# In server profile
mySystem.hardware.kernel = "stable";
```

#### Custom Kernel Selection
```nix
# For specific kernel versions
boot.kernelPackages = pkgs.linuxPackages_6_6;  # LTS
boot.kernelPackages = pkgs.linuxPackages_latest;  # Latest stable
```

## Automated vs Manual Updates

### Recommended Approach: **Manual with Automation Assistance**

#### Why Manual?
- **Control**: Review changes before applying
- **Testing**: Validate on development machines first
- **Rollback**: Immediate response to issues
- **Complexity**: Flake-based configs need careful handling

#### Automation Helpers

Create update scripts:
```bash
# scripts/update-check.sh
#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Checking for updates..."
nix flake update --commit-lock-file
nix flake check

echo "📊 Changes since last update:"
git log --oneline -10 flake.lock

echo "🧪 Testing build..."
sudo nixos-rebuild build --flake .#$(hostname)

echo "✅ Ready to apply with: sudo nixos-rebuild switch --flake .#$(hostname)"
```

#### Scheduled Checks (Optional)
```nix
# In machine configuration for development machines
systemd.timers.flake-update-check = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "weekly";
    Persistent = true;
  };
};

systemd.services.flake-update-check = {
  script = ''
    cd /etc/nixos
    ${pkgs.git}/bin/git fetch origin
    if [ "$(${pkgs.git}/bin/git rev-parse HEAD)" != "$(${pkgs.git}/bin/git rev-parse origin/main)" ]; then
      echo "Updates available in repository"
      # Send notification (optional)
    fi
  '';
  serviceConfig = {
    Type = "oneshot";
    User = "root";
  };
};
```

## Security Updates

### Critical Security Updates
- **Monitor**: NixOS security announcements
- **Apply**: Immediately for servers, within 24h for workstations
- **Test**: Quick smoke test, full testing can follow

### Process
```bash
# Emergency security update
nix flake update
sudo nixos-rebuild switch --flake .#$(hostname)

# Verify services
systemctl status
journalctl -f
```

## Best Practices

### 1. Staging Strategy
- **Development machines**: Test first
- **Desktop machines**: Apply after dev testing
- **Server machines**: Apply last with maintenance window

### 2. Documentation
- Keep upgrade log in git commits
- Document any manual interventions needed
- Note configuration changes required

### 3. Backup Strategy
- System generations (automatic with NixOS)
- Configuration repository (git)
- Important data (separate backup system)

### 4. Testing Checklist
- [ ] System boots successfully
- [ ] Network connectivity works
- [ ] Desktop environment loads (if applicable)
- [ ] Development tools function (if applicable)
- [ ] Container runtime works (if applicable)
- [ ] Custom services start correctly

## Troubleshooting

### Common Issues
1. **Build failures**: Check nixpkgs compatibility
2. **Service failures**: Review systemd logs
3. **Desktop issues**: Check display manager logs
4. **Container issues**: Verify runtime configuration

### Recovery
1. **Boot issues**: Use previous generation from GRUB
2. **Service issues**: Rollback and investigate
3. **Data corruption**: Restore from backup

## Monitoring

### Health Checks
```bash
# System health
systemctl --failed
journalctl -p err -b

# Nix store health
nix-store --verify --check-contents

# Disk usage
nix-store --gc --print-roots | wc -l
du -sh /nix/store
```

This upgrade strategy balances stability with staying current, providing clear procedures for different scenarios while maintaining the flexibility of your flake-based configuration.
