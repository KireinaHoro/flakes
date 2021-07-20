{ config, pkgs, ... }:

let
  iviDiviPrefix = "2a0c:b641:69c:cd0";
  gravityAddr = last: "${iviDiviPrefix}0::${last}/56";
  raitSecret = config.sops.secrets.rait.path;
  ifName = "enp0s25";
  prefixLength = 56;
in

{
  services.gravity = rec {
    enable = true;
    config = raitSecret;
    netnsAddress = gravityAddr "2";
    address = gravityAddr "1";
    subnet = gravityAddr "";
    group = 54;
    inherit prefixLength;
  };

  services.divi = {
    enable = true;
    prefix = "${iviDiviPrefix}4:0:4::/96";
    address = "${iviDiviPrefix}4:0:5:0:3/128";
    inherit ifName;
  };

  services.ivi = {
    enable = true;
    prefix4 = "10.172.208.0";
    prefix6 = "2a0c:b641:69c:cd05:0:5";
    defaultMap = "2a0c:b641:69c:f254:0:4::/96";
    inherit prefixLength;
  };
}
