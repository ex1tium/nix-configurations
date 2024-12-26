{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Example hostname
  networking.hostName = "elara";

  # Example SSH config (using the same SSH key on all machines)
  users.users.ex1tium = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      # Replace this line with your real SSH public key(s).
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD..."
    ];
  };

  # Example usage of sops-nix + GPG
  imports = [
    "${pkgs.path}/nixos/modules/security/ssh/sshd.nix"
    ../..//modules/features/secrets.nix
  ];

  # You can store your private GPG key in an encrypted sops-nix file
  # and have NixOS place it in /home/ex1tium/.gnupg or similar location if needed.

  services.openssh.enable = true;
  # More system config ...
}
