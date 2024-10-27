{ config, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = with pkgs; {
      rait-node-key = {};
      forward_wg_ipv4 = userToSops config.users.users.forward_ipv4;
      remote-access-priv = userToSops config.users.users.systemd-network;
      inadyn-cfg = userToSops config.users.users.inadyn;
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # emulate aarch64 for building
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  time.timeZone = "Asia/Shanghai";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.jsteward.shell = pkgs.zsh;

  # port forwarding user
  users.users.forward_ipv4 = {
    group = "forward_ipv4";
    isSystemUser = true;
  };
  users.groups.forward_ipv4 = {};

  nix.settings.substituters = [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];
  environment.systemPackages = with pkgs; [ gnupg dig ];

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

  # maintenance
  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "github:KireinaHoro/flakes";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

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

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
}

