{ pkgs, inputs, ... }:

{
  imports = [
    inputs.vscode-server.homeModules.default
    ../../hm-modules/home-common.nix
  ];

  home.packages = with pkgs; [
    texlive.combined.scheme-full
    gnumake
    python314Packages.pygments
    jetbrains.idea
  ];
  services.vscode-server.enable = true;
}
