{ config, pkgs, ... }:

let
  username = "jsteward";
in

{
  home-manager.users."${username}" = {
    home = {
      packages = with pkgs; [
        texlive.combined.scheme-full
        gnumake
        python310Packages.pygments
      ];
    };
  };
}
