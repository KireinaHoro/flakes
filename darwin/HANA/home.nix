{ pkgs, inputs, ... }:

{
  imports = [
    ../../hm-modules/home-common.nix
    inputs.mac-app-util.homeManagerModules.default
  ];

  home = {
    packages = with pkgs; [
      coreutils clang
      git git-lfs git-filter-repo
      gtkwave python3
      texlive.combined.scheme-full
      yubikey-manager smartmontools baobab
      imagemagick htop mtr
      darktable-app
    ];
  };

  programs.neovim = {
    enable = true;
    withPython3 = false;
    withRuby = false;
  };
}
