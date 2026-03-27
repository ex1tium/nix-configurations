{ pkgs, ... }:

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
      enableWayland = true;
    };

    features.distrobox.enable = true;

    hardware = {
      kernel = "stable";
      gpu.detection = "intel";
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

  services.twingate.enable = true;

  powerManagement.enable = true;

  # Host-local compatibility for non-Nix dynamically linked binaries
  # (e.g. VS Code extensions, distrobox-exported binaries, Claude).
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc   # libstdc++, libgcc_s — needed by most compiled binaries
      zlib           # ubiquitous compression library
      openssl        # TLS — needed by many Rust/Go binaries
    ];
  };

  systemd.sleep.settings = {
    Sleep = {
      SuspendState = "mem";
      HibernateDelaySec = "1h";
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

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "fi";
    variant = "";
  };

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

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

#  nixpkgs.config.permittedInsecurePackages = [
#    "intel-media-sdk-23.2.2"
#  ];

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
    gcc        # C compiler / cc wrapper — required by Rust (and cargo) to link binaries
    binutils   # ld, ar, etc. — GNU linker toolchain
  ];

  specialisation = {
    rescue.configuration = {
      imports = [
        ./specialisations/rescue-common.nix
        ./specialisations/rescue.nix
      ];
    };

    rescue-cli.configuration = {
      imports = [
        ./specialisations/rescue-common.nix
        ./specialisations/rescue-cli.nix
      ];
    };
  };
}
