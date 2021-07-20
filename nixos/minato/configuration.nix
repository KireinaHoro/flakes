{ config, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = { rait = {}; };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Asia/Shanghai";

  networking = {
    hostName = "minato";
    useDHCP = false;
    interfaces.enp0s25.useDHCP = true;

    firewall.enable = false;

    proxy = {
      default = "http://192.168.0.15:7890/";
      noProxy = "127.0.0.1,localhost,internal.domain";
    };
  };

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.jsteward.shell = pkgs.zsh;

  nix.binaryCaches = [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];
  environment.systemPackages = with pkgs; [
    gnupg mtr dig
  ];

  programs = {
    mtr.enable = true;
    zsh.enable = true;
    ssh.startAgent = false;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryFlavor = "curses";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

  # maintenance
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  services.udev.packages = [ pkgs.yubikey-personalization ];
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

