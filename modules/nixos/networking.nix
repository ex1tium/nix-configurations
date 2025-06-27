# Networking NixOS Module
# Network configuration and services

{ config, lib, pkgs, ... }:

with lib;

{
  config = mkIf config.mySystem.enable {
    # Basic networking (core functionality only)
    networking = {
      # Hostname is set in core.nix

      # Network manager (enabled by default, can be overridden)
      networkmanager = {
        enable = mkDefault true;
        wifi.powersave = mkDefault false;
        dns = mkDefault "systemd-resolved";
      };

      # Use systemd-resolved for DNS
      nameservers = mkDefault [
        "1.1.1.1"      # Cloudflare
        "1.0.0.1"      # Cloudflare
        "8.8.8.8"      # Google
        "8.8.4.4"      # Google
      ];

      # Firewall configuration (basic security)
      firewall = {
        enable = mkDefault true;
        allowPing = mkDefault true;

        # Only essential ports (SSH)
        allowedTCPPorts = mkDefault [
          22  # SSH
        ];

        allowedUDPPorts = mkDefault [
          # No UDP ports by default
        ];
        
        # Allow specific interfaces (core only)
        trustedInterfaces = mkDefault [
          "lo"  # Loopback
        ];
      };
      
      # Disable IPv6 by default (can be enabled per machine)
      enableIPv6 = mkDefault false;
    };

    # Network optimization
    boot.kernel.sysctl = {
        # Network security
        "net.ipv4.conf.all.send_redirects" = mkDefault 0;
        "net.ipv4.conf.default.send_redirects" = mkDefault 0;
        "net.ipv4.conf.all.accept_redirects" = mkDefault 0;
        "net.ipv4.conf.default.accept_redirects" = mkDefault 0;
        "net.ipv4.conf.all.accept_source_route" = mkDefault 0;
        "net.ipv4.conf.default.accept_source_route" = mkDefault 0;
        "net.ipv4.conf.all.log_martians" = mkDefault 1;
        "net.ipv4.conf.default.log_martians" = mkDefault 1;
        "net.ipv4.icmp_echo_ignore_broadcasts" = mkDefault 1;
        "net.ipv4.icmp_ignore_bogus_error_responses" = mkDefault 1;
        "net.ipv4.tcp_syncookies" = mkDefault 1;
        "net.ipv4.tcp_rfc1337" = mkDefault 1;
        
        # Network performance
        "net.core.rmem_max" = mkDefault 134217728;
        "net.core.wmem_max" = mkDefault 134217728;
        "net.ipv4.tcp_rmem" = mkDefault "4096 12582912 134217728";
        "net.ipv4.tcp_wmem" = mkDefault "4096 12582912 134217728";
        "net.core.netdev_max_backlog" = mkDefault 5000;
        "net.ipv4.tcp_congestion_control" = mkDefault "bbr";
      };

    # DNS resolution
    services.resolved = {
      enable = mkDefault true;
      dnssec = mkDefault "allow-downgrade";
      domains = mkDefault [ "~." ];
      fallbackDns = [
        "1.1.1.1"
        "1.0.0.1"
        "8.8.8.8"
        "8.8.4.4"
      ];
      extraConfig = ''
        DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
        FallbackDNS=1.1.1.1 1.0.0.1
        Domains=~.
        DNSSEC=allow-downgrade
        DNSOverTLS=opportunistic
      '';
    };

    # Network time synchronization
    services.timesyncd = {
      enable = mkDefault true;
      servers = mkDefault [
        "time.cloudflare.com"
        "time.google.com"
        "pool.ntp.org"
      ];
    };

    # Wireless configuration (use NetworkManager by default)
    networking.wireless.enable = mkDefault false;

    # Essential network tools only
    environment.systemPackages = with pkgs; [
      # Core network tools
      inetutils
      dnsutils
      nettools
    ];

    # SSH configuration
    services.openssh = {
      enable = mkDefault true;
      settings = {
        # Security settings
        PasswordAuthentication = mkDefault true;  # Can be disabled per machine
        PermitRootLogin = mkDefault "no";
        X11Forwarding = mkDefault false;
        AllowUsers = mkDefault [ config.mySystem.user ];
        MaxAuthTries = mkDefault 3;
        ClientAliveInterval = mkDefault 300;
        ClientAliveCountMax = mkDefault 2;
        
        # Performance settings
        UseDns = mkDefault false;
        
        # Protocol settings
        Protocol = mkDefault 2;
        Port = mkDefault 22;
      };
      
      openFirewall = mkDefault true;
      
      # Host keys
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
    };

    # Fail2ban for intrusion prevention (servers)
    services.fail2ban = mkIf (!config.mySystem.features.desktop.enable) {
      enable = mkDefault true;
      maxretry = mkDefault 3;
      bantime = mkDefault "1h";
      
      jails = {
        ssh = ''
          enabled = true
          port = ssh
          filter = sshd
          logpath = /var/log/auth.log
          maxretry = 3
          bantime = 3600
        '';
      };
    };

    # Network monitoring (optional)
    services.vnstat = {
      enable = mkDefault false; # Enable per machine if needed
    };
  };
}
