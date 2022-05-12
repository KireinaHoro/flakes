{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:ce2";
  gravityAddr = last: "${iviDiviPrefix}0::${last}/${toString prefixLength}";
  # raitSecret = config.sops.secrets.rait.path;
  ifName = "enp0s3";
  prefixLength = 60;
  publicDNS = [ "2001:4860:4860::8888" "8.8.8.8" ];
  chinaServer = "114.114.114.114";
  gravityTable = 3500;
  gravityMark = 333;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "nagisa";
    useDHCP = false;
    firewall.enable = false;
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        DHCP = "ipv4";
        networkConfig = {
          LinkLocalAddressing = "ipv4";
          IPv6AcceptRA = "no";
        };
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.passwordAuthentication = false;

    /*
    gravity = rec {
      enable = true;
      config = raitSecret;
      netnsAddress = gravityAddr "2";
      address = gravityAddr "1";
      subnet = gravityAddr "";
      inherit prefixLength;
      inherit gravityTable;
    };
    */
  };
}
