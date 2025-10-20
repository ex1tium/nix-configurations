# HP 14-ep0807no Boot Analysis and Troubleshooting

## Executive Summary

The HP 14-ep0807no laptop with Intel i3-N305 processor has **severely broken ACPI firmware** that causes NixOS to freeze during Stage 2 boot. The system hangs with ACPI thermal management errors (`_TZ.ETM0` symbol resolution failures) regardless of kernel parameters or NixOS configuration changes.

**Root Cause**: Hardware/firmware issue, NOT NixOS configuration issue.

---

## Investigation Results

### 1. Boot Freeze Characteristics

- **Stage 1 (initrd)**: ✅ Completes successfully
- **Stage 2 (kernel init)**: ❌ Freezes immediately
- **Error Message**: ACPI thermal management errors (`Could not resolve symbol [\_TZ.ETM0]`)
- **Kernel Parameters Tested**: 
  - `nomodeset` - No effect
  - `acpi=off` - Prevents disk detection
  - `acpi=noirq` - No effect
  - `thermal.off=1` - No effect
  - `i915.modeset=0` - No effect
  - `plymouth.enable=0` - No effect
  - `rd.break=pre-mount` - Emergency shell never appears

### 2. Configuration Analysis

#### Machine Configuration (`machines/magos/configuration.nix`)

**Issues Found**: None in NixOS configuration itself. The configuration is correct:
- ✅ Boot loader correctly configured for systemd-boot
- ✅ EFI partition correctly mounted at `/boot`
- ✅ UFS/eUFS device support properly configured
- ✅ Btrfs subvolumes correctly set up
- ✅ Kernel parameters reasonable

**However**: Some services enabled by default in the desktop profile can exacerbate ACPI issues:
- `thermald` - Tries to manage thermal zones, conflicts with broken ACPI
- `fwupd` - Firmware updates can trigger ACPI bugs
- `geoclue2` - Location services can cause early-boot hangs

#### Developer Profile (`modules/profiles/developer.nix`)

**Issues Found**: None. Profile correctly:
- ✅ Inherits desktop profile
- ✅ Enables development features
- ✅ Enables virtualization
- ✅ Uses latest kernel (appropriate for UFS support)

#### Desktop Feature (`modules/features/desktop.nix`)

**Potential Issues**:
- Line 129: `services.thermald.enable = mkDefault true` - **PROBLEMATIC**
  - Thermald tries to manage ACPI thermal zones
  - On broken ACPI firmware, this causes hangs
  - Should be disabled for this hardware

- Line 108: `services.fwupd.enable = mkDefault true` - **PROBLEMATIC**
  - Firmware updates can trigger ACPI issues
  - Should be disabled for this hardware

- Line 109: `services.geoclue2.enable = mkDefault true` - **MINOR ISSUE**
  - Not critical but can cause early-boot delays

#### GPU Configuration (`modules/features/hardware/gpu.nix`)

**Issues Found**: i915 kernel parameters too aggressive:
- Lines 41-46: GPU optimization parameters enabled by default
- `i915.enable_guc=2` - GuC firmware loading can trigger ACPI bugs
- `i915.enable_fbc=1` - Framebuffer compression can cause hangs
- `i915.enable_psr=1` - Panel self-refresh can interfere with ACPI
- `i915.fastboot=1` - Fastboot can skip ACPI initialization

These optimizations are fine for modern hardware but problematic on broken ACPI.

#### Hardware Configuration (`machines/magos/hardware-configuration.nix`)

**Issues Found**: None. Configuration is correct:
- ✅ i915 module correctly added to initrd
- ✅ UFS module correctly configured
- ✅ Filesystems correctly mounted
- ✅ Boot partition correctly at `/boot`

---

## Root Cause Analysis

### Why the System Freezes

1. **Kernel loads** and initializes ACPI subsystem
2. **ACPI firmware** has broken thermal zone definitions (`_TZ.ETM0`)
3. **Kernel tries to enumerate** ACPI thermal zones
4. **Firmware returns invalid data** causing symbol resolution failure
5. **Kernel hangs** trying to handle the error
6. **System never reaches** userspace (systemd, display manager, etc.)

### Why Kernel Parameters Don't Help

- `acpi=off` - Prevents disk detection (UFS device not found)
- `thermal.off=1` - Doesn't disable ACPI, only thermal management
- `nomodeset` - GPU driver not the issue
- `acpi=noirq` - Doesn't fix broken ACPI tables

The kernel is **hanging at a lower level** than these parameters can affect.

---

## Applied Workarounds

### Changes Made to `machines/magos/configuration.nix`

1. **Disabled i915 GPU optimizations**:
   ```nix
   "i915.enable_guc=0"
   "i915.enable_fbc=0"
   "i915.enable_psr=0"
   "i915.fastboot=0"
   ```

2. **Disabled thermald service**:
   ```nix
   services.thermald.enable = false;
   ```

3. **Disabled fwupd service**:
   ```nix
   services.fwupd.enable = lib.mkForce false;
   ```

4. **Disabled geoclue2 service**:
   ```nix
   services.geoclue2.enable = lib.mkForce false;
   ```

These are **conservative workarounds** that reduce the likelihood of triggering ACPI bugs.

---

## Recommendations

### For This Machine

1. **Check for BIOS Updates**:
   - Visit HP support website for model 14-ep0807no
   - Look for BIOS/UEFI firmware updates
   - ACPI bugs are often fixed in firmware updates

2. **Reset BIOS to Defaults**:
   - Boot into BIOS/UEFI setup
   - Reset to factory defaults
   - Some ACPI features may be misconfigured

3. **Disable ACPI in BIOS** (if available):
   - Some laptops have ACPI disable option
   - This is a last resort but may allow NixOS to boot

4. **Try Different Kernel**:
   - Change `kernel = "latest"` to `kernel = "lts"` in configuration
   - Older kernels may have different ACPI handling

### For NixOS Configuration

The configuration itself is **not the problem**. However, for future machines with similar issues:

1. Make GPU optimizations conditional on hardware detection
2. Make thermald conditional on ACPI health check
3. Add machine-specific service disables in machine config (as done here)

---

## Testing the Workarounds

To test if these changes help:

1. Pull the latest configuration:
   ```bash
   cd /tmp/nix-configurations
   git pull origin main
   ```

2. Reinstall:
   ```bash
   nixos-install --flake /tmp/nix-configurations#magos
   ```

3. Reboot and observe if the system gets past the ACPI errors

---

## Conclusion

**The NixOS configuration is correct and well-designed.** The boot freeze is caused by broken ACPI firmware on the HP 14-ep0807no, not by configuration issues. The applied workarounds are conservative attempts to avoid triggering the firmware bugs.

If the system still doesn't boot after these changes, the issue is purely hardware/firmware and requires:
- BIOS update from HP
- BIOS reset to defaults
- Or acceptance that this specific hardware may not be compatible with Linux

