# NixOS Configuration Architecture

## Design Principles

1. **Single Source of Truth**: Each configuration aspect should be defined in exactly one place
2. **Unidirectional Dependencies**: Dependencies flow downward only, no circular references
3. **Composable Features**: Features can be mixed and matched without conflicts
4. **Profile-Centric**: Profiles are the main entry points that define system roles
5. **Machine Overrides**: Machine-specific configs only override, never define base functionality

## Layer Structure

### Layer 1: Core Modules (Foundation)
**Purpose**: Provide essential system functionality
**Location**: `modules/core/`
**Dependencies**: None (only nixpkgs)

```
modules/core/
├── system.nix          # Basic system settings (hostname, timezone, etc.)
├── users.nix           # User management
├── networking.nix      # Network configuration
├── security.nix        # Security hardening
└── nix.nix            # Nix daemon configuration
```

**Characteristics**:
- No feature flags or conditionals
- Provide sensible defaults for all systems
- Use `mkDefault` for all options (can be overridden)

### Layer 2: Feature Modules (Composable)
**Purpose**: Implement specific functionality that can be enabled/disabled
**Location**: `modules/features/`
**Dependencies**: Core modules only

```
modules/features/
├── desktop/
│   ├── plasma.nix      # KDE Plasma 6
│   ├── gnome.nix       # GNOME
│   └── common.nix      # Common desktop functionality
├── development/
│   ├── languages/      # Language-specific tools
│   ├── editors/        # Editor configurations
│   └── containers.nix  # Development containers
├── virtualization/
│   ├── docker.nix      # Docker configuration
│   ├── libvirt.nix     # KVM/QEMU
│   └── common.nix      # Common virtualization
└── server/
    ├── monitoring.nix  # System monitoring
    ├── backup.nix      # Backup solutions
    └── web.nix         # Web server capabilities
```

**Characteristics**:
- Each feature is self-contained
- Can be enabled independently
- Use feature flags: `config.mySystem.features.desktop.enable`
- No conflicts between features

### Layer 3: Profiles (Role Definitions)
**Purpose**: Define complete system roles by combining features
**Location**: `modules/profiles/`
**Dependencies**: Feature modules

```
modules/profiles/
├── base.nix           # Minimal system (core only)
├── desktop.nix        # Desktop workstation
├── developer.nix      # Development machine
└── server.nix         # Server system
```

**Characteristics**:
- Main entry points for system configuration
- Define which features are enabled
- Set profile-specific defaults
- No implementation details (delegate to features)

### Layer 4: Machine Configuration (Overrides)
**Purpose**: Machine-specific customizations
**Location**: `machines/*/`
**Dependencies**: One profile

**Characteristics**:
- Choose one profile
- Override specific settings for hardware/use case
- Add machine-specific packages/services
- No base functionality implementation

## Example Implementation

### Profile Definition (Clean)
```nix
# modules/profiles/developer.nix
{ config, lib, ... }:
{
  imports = [
    ./desktop.nix  # Inherit desktop functionality
  ];

  # Enable development features
  mySystem.features = {
    development = {
      enable = true;
      languages = [ "nodejs" "go" "python" "rust" "nix" ];
      editors = [ "vscode" "neovim" ];
    };
    
    virtualization = {
      enable = true;
      docker = true;
      libvirt = true;
    };
  };

  # Profile-specific defaults
  mySystem.defaults = {
    kernel = "latest";
    autoUpgrade = false;  # Developers manage updates manually
  };
}
```

### Feature Implementation (Focused)
```nix
# modules/features/development/languages/nodejs.nix
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.mySystem.features.development.nodejs.enable {
    environment.systemPackages = with pkgs; [
      nodejs_latest
      nodePackages.npm
      nodePackages.yarn
      nodePackages.pnpm
    ];

    # Development-specific networking
    networking.firewall.allowedTCPPorts = [ 3000 8000 8080 ];
  };
}
```

### Machine Override (Minimal)
```nix
# machines/my-laptop/configuration.nix
{ ... }:
{
  # Use developer profile
  imports = [ ../../modules/profiles/developer.nix ];

  # Machine-specific overrides
  mySystem = {
    hostname = "my-laptop";
    hardware.gpu = "nvidia";
  };

  # Machine-specific packages
  environment.systemPackages = with pkgs; [
    jetbrains.idea-ultimate  # Upgrade from community
  ];
}
```

## Benefits of This Architecture

1. **No Conflicts**: Each layer has clear responsibilities
2. **Easy to Follow**: Dependencies flow in one direction
3. **Highly Reusable**: Features can be mixed and matched
4. **Simple Debugging**: Easy to trace where settings come from
5. **Maintainable**: Changes are localized to appropriate layers
6. **Extensible**: New features/profiles can be added easily

## Migration Strategy

1. **Extract Features**: Move feature-specific code from profiles to feature modules
2. **Simplify Profiles**: Profiles become feature enablement + defaults
3. **Clean Core**: Core modules provide foundation without conditionals
4. **Minimize Machines**: Machine configs only override, don't implement

This creates a clean, maintainable system where each component has a single responsibility.
