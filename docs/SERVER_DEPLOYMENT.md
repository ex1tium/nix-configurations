# Server Deployment Guide

## Container-First Philosophy

This NixOS server configuration follows a **container-first approach** where:

- **Databases** run in containers (PostgreSQL, MySQL, Redis, etc.)
- **Monitoring** runs in containers (Prometheus, Grafana, etc.)
- **Applications** run in containers when possible
- **System services** are minimal and essential only

## Server Profile Features

### Included (System-Level)
- **Container Runtimes**: Docker, Podman, LXD
- **Virtualization**: KVM/QEMU, libvirt
- **Security**: Fail2ban, firewall, SSH hardening
- **Monitoring**: System-level monitoring only
- **Backup**: Essential backup tools (rsync, borgbackup)
- **Networking**: Essential network tools

### Excluded (Use Containers Instead)
- ❌ Database servers (PostgreSQL, MySQL, Redis)
- ❌ Monitoring services (Prometheus, Grafana)
- ❌ Development tools (kubectl, helm, terraform)
- ❌ GUI applications
- ❌ Desktop environments

## Deployment Examples

### 1. Database Server with Containers

```yaml
# docker-compose.yml for PostgreSQL
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    restart: unless-stopped
    secrets:
      - postgres_password

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

### 2. Monitoring Stack with Containers

```yaml
# docker-compose.yml for monitoring
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    environment:
      GF_SECURITY_ADMIN_PASSWORD_FILE: /run/secrets/grafana_password
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    restart: unless-stopped
    secrets:
      - grafana_password

  node-exporter:
    image: prom/node-exporter:latest
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:

secrets:
  grafana_password:
    file: ./secrets/grafana_password.txt
```

### 3. Web Application Stack

```yaml
# docker-compose.yml for web app
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
    depends_on:
      - app

  app:
    image: myapp:latest
    environment:
      DATABASE_URL: postgresql://user:pass@postgres:5432/myapp
      REDIS_URL: redis://redis:6379
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    secrets:
      - postgres_password

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

## Machine-Specific Additions

For specific server roles, add tools per-machine:

### Development/CI Server
```nix
# In machine configuration
environment.systemPackages = with pkgs; [
  # Infrastructure as Code
  terraform
  ansible
  
  # Kubernetes tools
  kubectl
  helm
  k9s
  
  # Development tools
  git
  nodejs
  python3
];
```

### Monitoring Server
```nix
# In machine configuration
services.prometheus.exporters.node.enable = true;

# Use containers for Prometheus/Grafana themselves
```

### Backup Server
```nix
# In machine configuration
environment.systemPackages = with pkgs; [
  rclone
  restic
  duplicity
];

services.borgbackup.repos = {
  # Configure backup repositories
};
```

## Security Hardening

The server profile includes basic security hardening:

### Included Security Features
- **Fail2ban**: Intrusion prevention
- **Firewall**: Restrictive by default
- **SSH**: Hardened configuration
- **Automatic updates**: Optional (disabled by default)

### Additional Security (Per-Machine)
```nix
# In machine configuration
services = {
  # Additional security tools
  lynis.enable = true;           # Security auditing
  rkhunter.enable = true;        # Rootkit detection
  
  # Enhanced monitoring
  auditd.enable = true;          # Audit daemon
  
  # Network security
  fail2ban.jails = {
    # Custom jail configurations
  };
};
```

## Container Management

### Docker Compose Management
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Update services
docker-compose pull
docker-compose up -d

# Backup volumes
docker run --rm -v myapp_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

### Podman Alternative
```bash
# Use podman-compose instead of docker-compose
podman-compose up -d

# Or use systemd integration
podman generate systemd --new --files --name myapp_postgres
sudo cp *.service /etc/systemd/system/
sudo systemctl enable --now container-myapp_postgres.service
```

### LXD Containers
```bash
# Create application container
lxc launch ubuntu:22.04 myapp
lxc exec myapp -- apt update
lxc exec myapp -- apt install -y postgresql

# Configure networking
lxc config device add myapp myport5432 proxy listen=tcp:0.0.0.0:5432 connect=tcp:127.0.0.1:5432
```

## Backup Strategy

### Container Data Backup
```bash
#!/bin/bash
# backup-containers.sh

# Backup Docker volumes
for volume in $(docker volume ls -q); do
  docker run --rm -v $volume:/data -v $(pwd)/backups:/backup alpine \
    tar czf /backup/${volume}_$(date +%Y%m%d).tar.gz -C /data .
done

# Backup container configurations
cp -r /path/to/docker-compose.yml backups/
cp -r /path/to/configs backups/
```

### System Backup
```bash
# Use borgbackup for system-level backups
borg create /path/to/repo::$(date +%Y%m%d) \
  /etc \
  /home \
  /var/lib/docker/volumes \
  --exclude /var/lib/docker/volumes/*/tmp
```

## Monitoring

### Container Monitoring
- Use Prometheus + Grafana in containers
- Monitor container metrics with cAdvisor
- Use node-exporter for host metrics

### Log Management
- Use centralized logging (ELK stack in containers)
- Configure log rotation for containers
- Monitor disk usage

## Best Practices

1. **Separation of Concerns**: System services vs. application services
2. **Data Persistence**: Use named volumes for important data
3. **Security**: Regular updates, secrets management
4. **Monitoring**: Monitor both host and containers
5. **Backup**: Regular automated backups
6. **Documentation**: Document all container configurations

This approach provides a clean separation between the NixOS system configuration and application deployments, making the system more maintainable and portable.
