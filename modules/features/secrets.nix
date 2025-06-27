# Secrets Management Configuration Module
# This module is responsible for managing system secrets using sops-nix with GPG
# sops-nix allows for secure storage of sensitive data in your NixOS configuration

{ config, pkgs, defaultUser ? "ex1tium", ... }:
{
  # Enable sops
  sops = {
    # Default path to the secrets file
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Configure GPG for secrets - use parameterized user
    gnupg = {
      home = "/home/${defaultUser}/.gnupg";
      sshKeyPaths = [];  # We're using pure GPG, not SSH keys
    };

    # Validate that the secrets file exists if we're using it
    validateSopsFiles = false;  # Set to true when secrets.yaml exists

    # Example secret definition (uncomment and modify as needed)
    # secrets = {
    #   example_secret = {
    #     # Optional: specify which users/groups can access this secret
    #     owner = defaultUser;
    #     group = "users";
    #     mode = "0400";
    #     # Specify the GPG key to use (optional if using default key)
    #     # gpgOwner = "1C9145DA3075392EBA7E271469B16C8E0113CBA2";
    #   };
    # };
  };
}
