{ config, pkgs, ... }:

{
  networking.domain = "jsteward.moe";

  users.users.jsteward = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    gc = { automatic = true; dates = "03:15"; };
  };
}
