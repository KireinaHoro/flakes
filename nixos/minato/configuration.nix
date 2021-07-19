# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Asia/Shanghai";

  networking = {
    hostName = "minato";
    useDHCP = false;
    interfaces.enp0s25.useDHCP = true;

    # TODO properly configure firewall
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
    vim wget tmux git zsh htop bat ripgrep # basic utils
    mtr iptables dig # networking
  ];
  programs.mtr.enable = true;
  programs.zsh.enable = true;

  services.openssh.enable = true;

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
}

