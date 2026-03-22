# Magos Rescue Configuration

Standalone GUI rescue target for `magos`, based on the pre-refactor baseline captured in commit `5d8e2f9655add85702103e9a5caf08e1269cf8ff`.

## Purpose

- Keep a separate `magos-rescue` flake target independent from the main `magos` daily-driver configuration.
- Preserve the same storage and boot layout as `magos` for recovery work.
- Provide a minimal Plasma desktop with VS Code available for local recovery tasks.
- Keep Twingate, Home Manager, and SOPS disabled.

## Build Targets

- `.#nixosConfigurations.magos-rescue.config.system.build.toplevel`
- `sudo nixos-rebuild switch --flake .#magos-rescue`
- `.#nixosConfigurations.magos-rescue-cli.config.system.build.toplevel`

## Notes

- `hardware-configuration.nix` reuses the live `magos` hardware definition.
- The main `magos` configuration no longer carries an inline `specialisation.rescue`; rescue is now a first-class separate system target.
- The CLI-only variant now lives at `magos-rescue-cli`.