{ lib, pkgs, ... }:

{
  system.nixos.tags = [ "rescue" ];

  mySystem = {
    hostname = "magos-rescue";
    user = "magos";
    stateVersion = "25.11";

    hardware = {
      kernel = "stable";
      thunderbolt.enable = true;
      debug = false;
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."cryptswap" = {
    device = "/dev/disk/by-partlabel/cryptswap";
  };

  networking.networkmanager.enable = true;

  services.hardware.bolt.enable = true;
  services.twingate.enable = lib.mkForce false;

  powerManagement.enable = true;
  systemd.sleep.settings = {
    Sleep = {
      AllowHibernation = false;
      AllowSuspendThenHibernate = false;
    };
  };

  time.timeZone = "Europe/Helsinki";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fi_FI.UTF-8";
    LC_IDENTIFICATION = "fi_FI.UTF-8";
    LC_MEASUREMENT = "fi_FI.UTF-8";
    LC_MONETARY = "fi_FI.UTF-8";
    LC_NAME = "fi_FI.UTF-8";
    LC_NUMERIC = "fi_FI.UTF-8";
    LC_PAPER = "fi_FI.UTF-8";
    LC_TELEPHONE = "fi_FI.UTF-8";
    LC_TIME = "fi_FI.UTF-8";
  };

  console.keyMap = "fi";

  services.xserver.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;

  services.printing.enable = lib.mkForce false;

  services.pulseaudio.enable = false;
  security.rtkit.enable = false;
  services.pipewire.enable = false;

  programs.firefox.enable = lib.mkForce false;

  users.users.magos = {
    description = "Magos";
    packages = with pkgs; [ ];
  };

  environment.systemPackages = with pkgs; [
    gitFull
    git-lfs
    gh
    vim
    curl
    wget
    pciutils
    usbutils
    btrfs-progs
    cryptsetup
  ];
}
