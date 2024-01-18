{ config, pkgs, ... }:

let
  username = "jsteward";
in

{
  home-manager.users."${username}" = { home = {
    stateVersion = "24.05";
    packages = with pkgs; [
      texlive.combined.scheme-full
      gnumake
      python310Packages.pygments
    ];
  }; };
}
