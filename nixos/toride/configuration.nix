{ config, pkgs, lib, ... }:

{
  # we are not a gravity node!
  sops.secrets = lib.mkForce {};

  # emulate aarch64 for building
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  time.timeZone = "Europe/Zurich";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.jsteward = {
    openssh.authorizedKeys.keys = [
      # allow backup connection from kage
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICt/1H/oZByq2sIlO8ZAo2dU/E7vC59iPU40toEarl/q backup@kage"
      # local connection from Windows
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGHVr2tiECV8WrO0L4QdtPyb0x3UV9CHolfo7irnN9be pengcheng@DESKTOP-IFJ6V2U"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCZWKHAxFO+Vgril5xEzucdJ/XTRmzD3+UM832uq4rzbB4xzeQ8MTC3d+DdALXBea7G6giubUeKm2yAqjjhwx901eI32vaBUdrH0/+miRFnd2zuCpThg+bBzKgj9B+uWTjqzq4TlkaaXppWIfliZftIkFNJgk8/TbhazErDjZSmFYEYTnSvipXpV4w/rHEqskADCkoHt/ZALhWl3JNXG+sDenwanLIcqtvXzjq1/UoDgL29Wv2nR9BAJ5zigkMggqZnhX2deU485dGQaFpZKHe4Ds00/m+LyJbpkOZx8IKnJmmO7r16kPXezksX1QTE3OKpAom+/SvUQtzujyohm8OE+R6N4740Ku13gjIrW+eWjyB/MjGG4G9F2Xomrjgrl8+uEaQX02XAhzM/X5dLIZEexdSVBMX+AAo2H8QMZaAGbn4N8TxIWnbPmZeEEZ1n18n39RIJMeu6rvAt2IBKFnO76sIi/oXaJovcm4vT9lbPU9iQbMmRfZLr9LYscj5hHDE= pengcheng@DESKTOP-IFJ6V2U"
    ];
    shell = pkgs.zsh;
  };

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

