{ config, pkgs, ... }:

let
  username = "jsteward";
in

{
  home-manager.users."${username}" = { home = {
    stateVersion = "21.03";
    packages = with pkgs; [
      texlive.combined.scheme-full
      gnumake
      python310Packages.pygments
    ];
  }; };
}
