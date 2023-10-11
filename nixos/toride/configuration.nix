{ config, pkgs, ... }:

{
#  sops = {
#    defaultSopsFile = ./secrets.yaml;
#    secrets = {
#      rait = {};
#      remote-access-priv = {};
#    };
#  };

  time.timeZone = "Europe/Zurich";

  i18n.defaultLocale = "en_US.UTF-8";

  # allow backup connection from kage
  users.users.jsteward.openssh.authorizedKeys.keys =
    config.users.users.jsteward.openssh.authorizedKeys.keys ++ [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICt/1H/oZByq2sIlO8ZAo2dU/E7vC59iPU40toEarl/q backup@kage"
    ];
  users.users.jsteward.shell = pkgs.zsh;

  environment = {
    systemPackages = with pkgs; [ dig stow ];
    shells = with pkgs; [ zsh ];
  };

  programs = {
    mtr.enable = true;
    zsh.enable = true;
    autojump.enable = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}

