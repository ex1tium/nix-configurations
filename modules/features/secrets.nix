{ config, pkgs, ... }:
let
  sopsModule = pkgs.callPackage (fetchTarball "https://github.com/Mic92/sops-nix/tarball/master") {};
in {
  imports = [ sopsModule.modules.sops ];

  # Example: Decrypt a GPG-encrypted file that sets up a private key or secrets
  # sops.secrets."private-gpg-key" = {
  #   source = ../../secrets/private-gpg-key.asc.enc;  # Replace with your real file path
  #   user = "ex1tium";
  #   group = "ex1tium";
  #   permissions = "0400";
  # };
}
