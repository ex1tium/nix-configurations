# Secrets Management Configuration Module
# This module is responsible for managing system secrets using sops-nix with GPG
# sops-nix allows for secure storage of sensitive data in your NixOS configuration

{ config, pkgs, ... }:
{
  # Enable sops
  sops = {
    # Default path to the secrets file
    defaultSopsFile = ../../secrets/secrets.yaml;
    
    # Configure GPG for secrets
    gnupg = {
      home = "/home/ex1tium/.gnupg";  # Your GPG home directory
      sshKeyPaths = [];  # We're using pure GPG, not SSH keys
    };
    
    # Automatically create directories for secrets
    defaultSymlinkPath = "/run/secrets";
    
    # Example secret definition (uncomment and modify as needed)
    # secrets = {
    #   example_secret = {
    #     # Specify the path where the decrypted secret will be mounted
    #     path = "/run/secrets/example_secret";
    #     # Optional: specify which users/groups can access this secret
    #     owner = "ex1tium";
    #     group = "users";
    #     mode = "0400";
    #     # Specify the GPG key to use (optional if using default key)
    #     # gpgOwner = "your-gpg-fingerprint";
    #   };
    # };
  };
}
