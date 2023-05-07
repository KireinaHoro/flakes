{ config, pkgs, ... }:

{
/*
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      rait = {};
      webdav-env = {};
    };
  }; */

  time.timeZone = "Europe/Zurich";

  i18n.defaultLocale = "en_US.UTF-8";

  programs = {
    mtr.enable = true;
    zsh.enable = true;
  };
}

