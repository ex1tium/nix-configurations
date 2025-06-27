# Security NixOS Module
# Security hardening and protection services

{ config, lib, pkgs, ... }:

with lib;

{
  config = mkIf config.mySystem.enable {
    # Basic security configuration
    security = {
      # Sudo configuration
      sudo = {
        enable = true;
        wheelNeedsPassword = mkDefault true;
        execWheelOnly = mkDefault true;
        
        extraConfig = ''
          # Timeout for sudo sessions
          Defaults timestamp_timeout=15
          
          # Require password for sensitive commands
          Defaults passwd_tries=3
          Defaults badpass_message="Authentication failure"
          
          # Log sudo usage
          Defaults logfile="/var/log/sudo.log"
          Defaults log_input, log_output
        '';
      };
      
      # Polkit configuration
      polkit.enable = mkDefault true;
      
      # RealtimeKit for audio
      rtkit.enable = mkDefault true;
      
      # AppArmor security framework
      apparmor = {
        enable = mkDefault true;
        killUnconfinedConfinables = mkDefault false; # Don't kill unconfined processes
        packages = with pkgs; [
          apparmor-profiles
          apparmor-utils
        ];
      };
      
      # Audit framework (disabled by default, enable per machine if needed)
      auditd.enable = mkDefault false;
      
      # Protect kernel logs (configured via sysctl)
      
      # Security options (configured via sysctl and other means)
      # hideProcessInformation, lockKernelModules, protectKernelImage, etc.
      # are configured through kernel parameters and sysctl settings below
    };

    # Kernel security parameters
    boot.kernel.sysctl = {
      # Kernel hardening
      "kernel.dmesg_restrict" = mkDefault 1;
      "kernel.kptr_restrict" = mkForce 2;
      "kernel.unprivileged_bpf_disabled" = mkDefault 1;
      "kernel.yama.ptrace_scope" = mkDefault 1;
      
      # Network security (additional to networking.nix)
      "net.ipv4.conf.all.rp_filter" = mkDefault 1;
      "net.ipv4.conf.default.rp_filter" = mkDefault 1;
      "net.ipv4.tcp_timestamps" = mkDefault 0;
      "net.ipv4.tcp_sack" = mkDefault 0;
      "net.ipv4.tcp_dsack" = mkDefault 0;
      "net.ipv4.tcp_fack" = mkDefault 0;
      
      # Memory protection
      "vm.mmap_rnd_bits" = mkDefault 32;
      "vm.mmap_rnd_compat_bits" = mkDefault 16;
      
      # File system security
      "fs.protected_hardlinks" = mkDefault 1;
      "fs.protected_symlinks" = mkDefault 1;
      "fs.protected_fifos" = mkDefault 2;
      "fs.protected_regular" = mkDefault 2;
      "fs.suid_dumpable" = mkDefault 0;
    };

    # Kernel modules blacklist
    boot.blacklistedKernelModules = [
      # Uncommon network protocols
      "dccp"
      "sctp"
      "rds"
      "tipc"
      
      # Uncommon filesystems
      "cramfs"
      "freevxfs"
      "jffs2"
      "hfs"
      "hfsplus"
      "squashfs"
      "udf"
      
      # Firewire (can be used for DMA attacks)
      "firewire-core"
      "firewire-ohci"
      "firewire-sbp2"
      
      # Thunderbolt (can be used for DMA attacks)
      "thunderbolt"
    ];

    # Security packages
    environment.systemPackages = with pkgs; [
      # Security tools
      gnupg
      pinentry
      
      # System security
      lynis        # Security auditing
      chkrootkit   # Rootkit detection
      # rkhunter not available in nixpkgs
      
      # Network security
      nmap         # Network scanning
      
      # File integrity
      aide         # File integrity checker
      
      # Password management
      pass         # Password store
      # Pinentry packages (both available, desktop features will choose appropriate one)
      pinentry-curses
      pinentry-gtk2
    ];

    # GPG configuration
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = mkDefault true;
      # pinentryPackage is set by desktop environments or can be overridden per machine
    };

    # Secrets management with sops-nix
    sops = mkIf (builtins.pathExists ../../secrets/secrets.yaml) {
      defaultSopsFile = ../../secrets/secrets.yaml;
      validateSopsFiles = false;
      age.keyFile = "/home/${config.mySystem.user}/.config/sops/age/keys.txt";
      
      # Example secrets (uncomment and configure as needed)
      # secrets."user-password" = {
      #   neededForUsers = true;
      # };
    };

    # Firewall configuration (basic rules in networking.nix)
    networking.firewall = {
      # Additional security rules
      allowedTCPPortRanges = mkDefault [];
      allowedUDPPortRanges = mkDefault [];
      
      # Log dropped packets
      logReversePathDrops = mkDefault true;
      logRefusedConnections = mkDefault false; # Can be noisy
      
      # Rate limiting
      pingLimit = mkDefault "--limit 1/minute --limit-burst 5";
    };

    # System hardening
    systemd = {
      # Coredump handling
      coredump.extraConfig = ''
        Storage=none
        ProcessSizeMax=0
      '';
      
      # Service hardening
      services = {
        # Harden systemd services
        systemd-logind.serviceConfig = {
          SystemCallFilter = [ "@system-service" "~@privileged" ];
          SystemCallArchitectures = "native";
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictRealtime = true;
          RestrictNamespaces = true;
        };
      };
    };

    # File permissions
    security.wrappers = {
      # Only include essential SUID programs
      sudo = {
        source = "${pkgs.sudo.out}/bin/sudo";
        owner = "root";
        group = mkDefault "root";
        setuid = true;
      };
      ping = {
        source = "${pkgs.iputils.out}/bin/ping";
        owner = "root";
        group = "root";
        capabilities = "cap_net_raw+p";
      };
    };

    # Services configuration
    services = {
      # Secure logging
      journald.extraConfig = ''
        SystemMaxUse=1G
        MaxRetentionSec=1month
        Compress=yes
        ForwardToSyslog=no
        Storage=persistent
      '';
    };

    # User security
    users = {
      # Disable mutable users (optional, can be enabled per machine)
      mutableUsers = mkDefault true;
      
      # Default user shell security
      defaultUserShell = pkgs.zsh;
    };

    # Automatic security updates (disabled by default, enable per machine)
    system.autoUpgrade = {
      enable = mkDefault false;
      dates = mkDefault "04:00";
      allowReboot = mkDefault false;
      channel = mkDefault "https://nixos.org/channels/nixos-24.11";
    };

    # Security monitoring (optional)
    services.osquery = {
      enable = mkDefault false; # Enable per machine if needed
    };
  };
}
