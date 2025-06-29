# Finnish Locale and Keyboard Configuration
# Provides Finnish keyboard layout with English language interface

{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    # Keyboard Layout Configuration
    services.xserver.xkb = {
      layout = mkDefault "fi";
      variant = mkDefault "";
      options = mkDefault "grp:alt_shift_toggle,compose:ralt";
    };

    # Console keyboard layout
    console = {
      keyMap = mkDefault "fi";
      font = mkDefault "Lat2-Terminus16";
    };

    # Locale Configuration - English interface with Finnish regional settings
    i18n = {
      defaultLocale = mkDefault "en_US.UTF-8";
      
      extraLocaleSettings = {
        # Keep English for system messages and interface
        LC_MESSAGES = mkDefault "en_US.UTF-8";
        LC_CTYPE = mkDefault "en_US.UTF-8";
        LC_COLLATE = mkDefault "en_US.UTF-8";
        
        # Use Finnish for regional formatting
        LC_ADDRESS = mkDefault "fi_FI.UTF-8";
        LC_IDENTIFICATION = mkDefault "fi_FI.UTF-8";
        LC_MEASUREMENT = mkDefault "fi_FI.UTF-8";
        LC_MONETARY = mkDefault "fi_FI.UTF-8";
        LC_NAME = mkDefault "fi_FI.UTF-8";
        LC_NUMERIC = mkDefault "fi_FI.UTF-8";
        LC_PAPER = mkDefault "fi_FI.UTF-8";
        LC_TELEPHONE = mkDefault "fi_FI.UTF-8";
        LC_TIME = mkDefault "fi_FI.UTF-8";
      };

      # Ensure required locales are available
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "fi_FI.UTF-8/UTF-8"
        "C.UTF-8/UTF-8"
      ];
    };

    # Time zone configuration
    time.timeZone = mkDefault "Europe/Helsinki";

    # Input method configuration for Finnish
    i18n.inputMethod = {
      enabled = mkDefault "ibus";
      ibus.engines = with pkgs.ibus-engines; [
        # Add Finnish input methods if needed
      ];
    };

    # Environment variables for proper locale handling
    environment.sessionVariables = {
      # Ensure proper locale handling
      LANG = mkDefault "en_US.UTF-8";
      LC_ALL = mkDefault "";  # Don't override individual LC_* settings
      
      # Finnish keyboard specific
      XKB_DEFAULT_LAYOUT = mkDefault "fi";
      XKB_DEFAULT_OPTIONS = mkDefault "grp:alt_shift_toggle,compose:ralt";
    };

    # Home Manager configuration for user-level locale settings
    home-manager.users.${config.mySystem.user} = {
      home.language = {
        base = "en_US.UTF-8";
        address = "fi_FI.UTF-8";
        monetary = "fi_FI.UTF-8";
        numeric = "fi_FI.UTF-8";
        time = "fi_FI.UTF-8";
        measurement = "fi_FI.UTF-8";
        paper = "fi_FI.UTF-8";
      };

      # User session variables
      home.sessionVariables = {
        LANG = "en_US.UTF-8";
        LC_TIME = "fi_FI.UTF-8";
        LC_MONETARY = "fi_FI.UTF-8";
        LC_NUMERIC = "fi_FI.UTF-8";
        LC_MEASUREMENT = "fi_FI.UTF-8";
        LC_PAPER = "fi_FI.UTF-8";
        LC_ADDRESS = "fi_FI.UTF-8";
        LC_TELEPHONE = "fi_FI.UTF-8";
      };
    };

    # KDE Plasma specific locale settings
    environment.etc."xdg/kdeglobals".text = mkIf config.mySystem.features.desktop.enable ''
      [Locale]
      Country=fi
      Language=en_US
      
      [Formats]
      DateFormat=d.M.yyyy
      TimeFormat=HH:mm:ss
      DecimalSymbol=,
      ThousandsSeparator= 
      CurrencySymbol=€
      MonetaryDecimalSymbol=,
      MonetaryThousandsSeparator= 
    '';

    # GTK applications locale settings
    environment.etc."gtk-3.0/settings.ini".text = mkIf config.mySystem.features.desktop.enable ''
      [Settings]
      gtk-application-prefer-dark-theme=0
      gtk-theme-name=Breeze
      gtk-icon-theme-name=breeze
      gtk-font-name=Noto Sans 10
      gtk-cursor-theme-name=breeze_cursors
      gtk-cursor-theme-size=24
      gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
      gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
      gtk-button-images=0
      gtk-menu-images=0
      gtk-enable-event-sounds=1
      gtk-enable-input-feedback-sounds=0
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle=hintslight
      gtk-xft-rgba=rgb
    '';

    # Fonts with Finnish character support
    fonts.packages = with pkgs; [
      # Ensure proper Finnish character support
      noto-fonts
      noto-fonts-cjk-sans
      liberation_ttf
      dejavu_fonts
      
      # Finnish-specific fonts if needed
      # Add any specific Finnish fonts here
    ];

    # Spell checking for Finnish and English
    environment.systemPackages = with pkgs; [
      # Spell checking dictionaries
      hunspell
      hunspellDicts.en_US
      hunspellDicts.fi_FI
      
      # Additional language tools
      aspell
      aspellDicts.en
      aspellDicts.fi
    ];

    # LibreOffice language configuration
    environment.etc."libreoffice/registry/main.xcd".text = mkIf config.mySystem.features.desktop.enable ''
      <?xml version="1.0" encoding="UTF-8"?>
      <oor:data xmlns:oor="http://openoffice.org/2001/registry">
        <oor:component-data oor:name="Linguistic" oor:package="org.openoffice.Office">
          <node oor:name="General">
            <prop oor:name="DefaultLocale" oor:type="xs:string">
              <value>en-US</value>
            </prop>
            <prop oor:name="UILocale" oor:type="xs:string">
              <value>en-US</value>
            </prop>
          </node>
        </oor:component-data>
      </oor:data>
    '';

    # Firefox language preferences
    programs.firefox = mkIf config.mySystem.features.desktop.enable {
      preferences = {
        "intl.accept_languages" = "en-US,en,fi";
        "intl.locale.requested" = "en-US";
        "spellchecker.dictionary" = "en-US,fi";
      };
    };
  };
}
