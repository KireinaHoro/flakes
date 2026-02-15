{ pkgs, ... }:

{
  imports = [ ../../hm-modules/home-common.nix ];

  home = {
    packages = with pkgs; [
      coreutils clang git git-lfs gtkwave python3
      texlive.combined.scheme-full
      yubikey-manager smartmontools baobab
      imagemagick htop
    ];
  };

  programs.neovim.enable = true;
}
