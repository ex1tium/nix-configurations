# Magos Rescue CLI Configuration

Standalone headless rescue target for `magos`.

## Purpose

- Keep a separate `magos-rescue-cli` flake target for low-overhead recovery work.
- Preserve the same storage and boot layout as `magos` for repair tasks.
- Stay minimal: no desktop session, no Twingate, no Home Manager, and no SOPS dependency.

## Build Targets

- `.#nixosConfigurations.magos-rescue-cli.config.system.build.toplevel`
- `sudo nixos-rebuild switch --flake .#magos-rescue-cli`

## Notes

- `hardware-configuration.nix` reuses the live `magos` hardware definition.
- The GUI-capable rescue environment now lives at `magos-rescue`.