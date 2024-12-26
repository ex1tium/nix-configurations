{ config, pkgs, ... }:
{
  # Enable networking.
  networking.networkmanager.enable = true;

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 3389 ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}
