{ pkgs, ... }:

{
  imports = [ ../../hm-modules/home-common.nix ];

  home = {
    packages = with pkgs; [
      coreutils clang git
      texlive.combined.scheme-full
    ];
  };

  # disable GUI for vim
  programs.vim.packageConfigurable = pkgs.vim;

  programs.neovim.enable = true;
}
