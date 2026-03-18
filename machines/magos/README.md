# Magos Machine Configuration

Fresh baseline for `magos`, rebuilt from the currently deployed `/etc/nixos` generation.

## Source of Truth

- `configuration.nix`: translated from `/etc/nixos/configuration.nix`
- `hardware-configuration.nix`: copied from `/etc/nixos/hardware-configuration.nix`
- `disko.nix`: copied from `/etc/nixos/disko.nix`

## Current Layout

- **Boot**: `systemd-boot` on EFI
- **Root**: LUKS-on-Btrfs with `@root`, `@home`, `@nix`, `@persist`, `@snapshots`
- **Swap**: encrypted `cryptswap`
- **Desktop**: Plasma 6 with SDDM
- **Audio**: PipeWire

## Notes

- This machine uses the `base` profile in `flake.nix` and imports the desktop feature module directly in `machines/magos/configuration.nix`.
- Home Manager is bound to the machine user `magos` through the flake machine definition.
