{ pkgs, ... }:

{
  imports = [ ../../hm-modules/home-common.nix ];

  home = {
    packages = with pkgs; [
      coreutils clang git gtkwave
      texlive.combined.scheme-full
      yubikey-manager
    ];
  };

  programs.neovim.enable = true;
}
