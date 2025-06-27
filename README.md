# Modern NixOS Configuration System

A modular, layered NixOS configuration system designed for easy maintenance and reusability across multiple machines and use cases.

## 🏗️ Architecture

This configuration follows a **layered architecture** with unidirectional dependencies:

```
Machine → Profile → Features → Core
```

- **Core**: Foundation services (networking, users, security)
- **Features**: Composable functionality (desktop, development, virtualization)
- **Profiles**: Role-based combinations (desktop, developer, server)
- **Machines**: Hardware-specific overrides and customizations

## 🚀 Quick Start

### Prerequisites
- NixOS 25.05 or compatible system
- Flakes enabled: `nix.settings.experimental-features = ["nix-command" "flakes"]`

### Deploy to New Machine

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ex1tium/nix-configurations.git
   cd nix-configurations
   ```

2. **Generate hardware configuration**:
   ```bash
   sudo nixos-generate-config --root /mnt
   mkdir -p machines/my-machine
   cp /mnt/etc/nixos/hardware-configuration.nix machines/my-machine/
   ```

3. **Create machine configuration**:
   ```bash
   cp machines/elara/configuration.nix machines/my-machine/
   # Edit machines/my-machine/configuration.nix for your needs
   ```

4. **Add machine to flake**:
   ```nix
   # In flake.nix, add to machines = { ... }:
   my-machine = {
     system = "x86_64-linux";
     profile = "developer";  # or "desktop", "server"
     hostname = "my-machine";
     users = [ globalConfig.defaultUser ];
   };
   ```

5. **Build and deploy**:
   ```bash
   sudo nixos-rebuild switch --flake .#my-machine
   ```

## 📋 Available Profiles

### Desktop Profile
- **Target**: Basic desktop workstations, thin clients
- **Features**: KDE Plasma 6, essential applications
- **Use Case**: General productivity, media consumption

### Developer Profile
- **Target**: Development workstations, daily drivers
- **Features**: Desktop + development tools + virtualization
- **Languages**: Node.js, Go, Python, Rust, Nix
- **Tools**: VS Code, containers (Docker/Podman), KVM

### Server Profile
- **Target**: Headless servers, container hosts
- **Features**: Monitoring, containers, security hardening
- **Use Case**: Production servers, self-hosted services

## 🔧 Customization

### Adding a New Machine

1. Create machine directory: `machines/{hostname}/`
2. Add hardware configuration and machine-specific settings
3. Choose appropriate profile and override as needed
4. Register in `flake.nix`

### Enabling Features

Features are controlled through the `mySystem.features` option:

```nix
mySystem.features = {
  desktop.enable = true;
  development = {
    enable = true;
    languages = [ "nodejs" "python" "rust" ];
    editors = [ "vscode" "neovim" ];
  };
  virtualization = {
    enable = true;
    enableDocker = true;
    enableLibvirt = true;
  };
};
```

### Container-First Philosophy

- **Databases**: Run PostgreSQL, MySQL, Redis in containers
- **Services**: Use Docker Compose for development services
- **Virtualization**: LXC/LXD preferred over VirtualBox

## 🛠️ Development

### Available Dev Shells

```bash
nix develop .#nodejs    # Node.js development
nix develop .#go        # Go development
nix develop .#python    # Python development
nix develop .#rust      # Rust development
```

### Useful Commands

```bash
# Update flake inputs
nix run .#update

# Check configuration
nix run .#check

# Format code
nix fmt

# Clean up
sudo nix-collect-garbage -d
```

## 📚 Documentation

- [Architecture Details](docs/ARCHITECTURE.md) - Detailed design principles
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions

## 🔒 Security

- Secrets managed with [SOPS](https://github.com/Mic92/sops-nix)
- Security hardening in server profile
- Fail2ban and firewall configuration
- Regular security updates

## 🤝 Contributing

1. Follow the layered architecture principles
2. Use `mkDefault` for overrideable options
3. Keep features self-contained and composable
4. Test changes with `nix flake check`
5. Update documentation for new features

## 📄 License

This configuration is provided as-is for educational and personal use.