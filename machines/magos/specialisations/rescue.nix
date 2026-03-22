{ lib, pkgs, ... }:

{
  mySystem.features.desktop = {
    enable = lib.mkForce true;
    environment = lib.mkForce "plasma";
    displayManager = lib.mkForce "sddm";
    enableWayland = lib.mkForce true;
    enableX11 = lib.mkForce true;
  };

  environment.systemPackages = [ pkgs.vscode ];
}