{ lib, ... }:

{
  system.nixos.tags = [ "rescue" ];

  mySystem.features.distrobox.enable = lib.mkForce false;

  services.twingate.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;

  powerManagement.enable = true;
  systemd.sleep.settings = {
    Sleep = {
      AllowHibernation = false;
      AllowSuspendThenHibernate = false;
    };
  };

  services.pulseaudio.enable = lib.mkForce false;
  security.rtkit.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;

  programs.firefox.enable = lib.mkForce false;

  users.users.magos.packages = lib.mkForce [ ];
}