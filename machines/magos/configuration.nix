{ lib, pkgs, ... }:

{
  imports = [
    ../../modules/features/desktop.nix
    ../../modules/features/distrobox.nix
  ];

  mySystem = {
    hostname = "magos";
    user = "magos";
    stateVersion = "25.11";

    features.desktop = {
      enable = true;
      environment = "plasma";
      displayManager = "sddm";
      enableX11 = true;
      enableWayland = false;
    };

    features.distrobox.enable = true;

    hardware = {
      kernel = "stable";
      gpu.detection = "intel";
      thunderbolt.enable = true;
      debug = true;
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."cryptswap" = {
    device = "/dev/disk/by-partlabel/cryptswap";
  };

  networking.networkmanager.enable = true;

  services.hardware.bolt.enable = true;

  services.twingate.enable = true;

  powerManagement.enable = true;
  systemd.sleep.extraConfig = ''
    AllowHibernation=no
    AllowSuspendThenHibernate=no
  '';

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

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "fi";
    variant = "";
  };

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasmax11";
  services.displayManager.sddm = {
    wayland.enable = lib.mkForce false;
    settings.General.DisplayServer = "x11";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.extraConfig."10-disable-libcamera-monitor" = {
      "wireplumber.profiles" = {
        main = {
          "monitor.libcamera" = "disabled";
        };
      };
    };
  };

  programs.firefox.enable = true;

  users.users.magos = {
    description = "Magos";
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  environment.systemPackages = with pkgs; [
    vscode
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
