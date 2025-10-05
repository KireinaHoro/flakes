{ pkgs, inputs, ... }:

{
  imports = [
    inputs.vscode-server.homeModules.default
    ../../hm-modules/home-common.nix
  ];

  home.packages = with pkgs; [
    texlive.combined.scheme-full
    gnumake
    python310Packages.pygments
  ];
  services.vscode-server.enable = true;
}
