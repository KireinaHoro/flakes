{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:cf1";
  gravityAddrSingle = last: "${iviDiviPrefix}0::${last}";
  gravityAddr = last: "${gravityAddrSingle last}/${toString prefixLength}";
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

    gravity = {
      enable = true;
      config = config.sops.secrets.rait.path;
      netnsAddress = gravityAddr "2";
      address = gravityAddr "1";
      subnet = gravityAddr "";
      inherit prefixLength;
      inherit gravityTable;
    };

    webdav = {
      enable = true;
      environmentFile = config.sops.secrets.webdav-env.path;
      settings = {
        address = "[${gravityAddrSingle "1"}]"; # only listen in gravity
        port = 8080;
        scope = "/srv/shared";
        modify = false;
        auth = true;
        users = [
          {
            username = "{env}ZOT_USERNAME";
            password = "{env}ZOT_PASSWORD";
            rules = [
              { allow = false; path = "/"; }
              { allow = true; modify = true; path = "/zotero"; }
            ];
          }
        ];
      };
    };
  };
}
