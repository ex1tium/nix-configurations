# Magos Rescue Configuration

Standalone rescue target for `magos`, based on the pre-refactor baseline captured in commit `5d8e2f9655add85702103e9a5caf08e1269cf8ff`.

## Purpose

- Keep a separate `magos-rescue` flake target independent from the main `magos` daily-driver configuration.
- Preserve the same storage and boot layout as `magos` for recovery work.
- Stay lightweight: no desktop session, no Twingate, no Home Manager, and no SOPS dependency.

## Build Targets

- `.#nixosConfigurations.magos-rescue.config.system.build.toplevel`
- `sudo nixos-rebuild switch --flake .#magos-rescue`

## Notes

- `hardware-configuration.nix` reuses the live `magos` hardware definition.
- The main `magos` configuration no longer carries an inline `specialisation.rescue`; rescue is now a first-class separate system target.