{ config, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      rait = {};
      monzoon_env = {};
    };
  };

  time.timeZone = "Europe/Zurich";

  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [ xfsprogs stow gnupg lm_sensors dig ];

  users.users.root.openssh.authorizedKeys.keys =
    config.users.users.jsteward.openssh.authorizedKeys.keys;

  programs = {
    mtr.enable = true;
    zsh.enable = true;
    ssh.startAgent = false;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-curses;
    };
  };

  services.pcscd.enable = true;

  # allow jsteward to use local smartcard over SSH
  security.polkit.extraConfig = ''
    /* allow jsteward to access PC/SC smartcards */
    polkit.addRule(function(action, subject) {
      if (action.id == "org.debian.pcsc-lite.access_pcsc" && subject.user == "jsteward") {
        return polkit.Result.YES;
      }
    });

    polkit.addRule(function(action, subject) {
      if (action.id == "org.debian.pcsc-lite.access_card" && subject.user == "jsteward") {
        return polkit.Result.YES;
      }
    });
  '';
}

