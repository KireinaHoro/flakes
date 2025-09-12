{ config, pkgs, inputs, ... }:

let
  username = "jsteward";
in

{
  home-manager.users."${username}" = {
    imports = [
      inputs.vscode-server.homeModules.default
    ];
    home = {
      packages = with pkgs; [
        texlive.combined.scheme-full
        gnumake
        python310Packages.pygments
      ];
    };
    services.vscode-server.enable = true;
  };
}
