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

    openssh.settings.PasswordAuthentication = false;

    gravity = {
      enable = true;
      config = config.sops.secrets.rait.path;
      netnsAddress = gravityAddr "2";
      address = gravityAddr "1";
      subnet = gravityAddr "";
      # defaultRoute = true;
      inherit prefixLength;
      inherit gravityTable;
    };

    webdav = {
      enable = true;
      environmentFile = config.sops.secrets.webdav-env.path;
      settings = {
        address = "localhost";
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

    nginx = {
      enable = true;
      clientMaxBodySize = "100m";
      virtualHosts = {
        "nagisa.jsteward.moe" = {
          forceSSL = true;
          enableACME = true;
          serverAliases = [ "nagisa.g.jsteward.moe" ];
        };
        "nagisa.g.jsteward.moe" = {
          listen = [
            { addr = "[${gravityAddrSingle "1"}]"; port = 8080; ssl = true; }
            { addr = "10.0.0.248"; port = 8080; ssl = true; } # public IPv4
          ];
          forceSSL = true;
          useACMEHost = "nagisa.jsteward.moe";
          locations = {
            "/" = {
              proxyPass = "http://localhost:8080";
              extraConfig = ''
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header REMOTE-HOST $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Host $host;
                proxy_redirect off;
              '';
            };
          };
        };
      };
    };
  };
}
