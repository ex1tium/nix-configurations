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
- **Containers**: Podman + Distrobox

## Notes

- This machine uses the `base` profile in `flake.nix` and imports the desktop feature module directly in `machines/magos/configuration.nix`.
- Distrobox is enabled through the dedicated `modules/features/distrobox.nix` module and does not pull in the full virtualization stack.
- The default Distrobox container set includes `fedora-toolbox` on Fedora 43 and `ubuntu-toolbox` on Ubuntu 24.04.
- Home Manager is bound to the machine user `magos` through the flake machine definition.
- Rescue boot variants are implemented as `specialisation.rescue` and `specialisation.rescue-cli` under this machine.
- `rescue` keeps a minimal Plasma session with VS Code available.
- `rescue-cli` disables the desktop stack and keeps a low-overhead recovery environment.
