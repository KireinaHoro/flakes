{ config, pkgs, ... }:

let
  prefixNoMask = "2a0c:b641:69c:cd00";
  raitSecret = config.sops.secrets.rait.path;
  ifName = "enp0s25";
in

{
  services.gravity = rec {
    enable = true;
    config = raitSecret;
    netnsAddress = "${prefixNoMask}::2/56";
    address = "${prefixNoMask}::1/56";
    subnet = "${prefixNoMask}::/56";
    group = 54;
    prefixLength = 56;
  };

  services.divi = {
    enable = true;
    prefix = "${prefixNoMask}:0:4::/96";
    address = "${prefixNoMask}:0:5:0:3/128";
    inherit ifName;
  };
}
