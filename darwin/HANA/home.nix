{ pkgs, ... }:

{
  imports = [ ../../hm-modules/home-common.nix ];

  home = {
    packages = with pkgs; [
      coreutils clang git gtkwave
      texlive.combined.scheme-full
    ];
  };

  programs.neovim.enable = true;
}
