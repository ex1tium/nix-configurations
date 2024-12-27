# Network Configuration Module
# This module handles all networking-related settings including
# network management, firewall rules, and SSH access

{ config, pkgs, ... }:
{
  # Network Management
  networking.networkmanager = {
    enable = true;  # Enable NetworkManager for network configuration
                   # This provides a standard interface for managing network connections
  };

  # Firewall Configuration
  networking.firewall = {
    enable = true;          # Enable the firewall for security
    allowedTCPPorts = [
      3389                 # RDP port for remote desktop access
    ];
    # Note: Add more ports here if needed, for example:
    # 80 (HTTP), 443 (HTTPS), 22 (SSH), etc.
  };

  # SSH Server Configuration
  services.openssh = {
    enable = true;         # Enable OpenSSH server
                          # Allows secure remote access to the system
  };
}
