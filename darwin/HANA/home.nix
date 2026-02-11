{ pkgs, ... }:

{
  imports = [ ../../hm-modules/home-common.nix ];

  home = {
    packages = with pkgs; [
      coreutils clang git gtkwave python3
      texlive.combined.scheme-full
      yubikey-manager smartmontools baobab
    ];
  };

  programs.neovim.enable = true;
}
