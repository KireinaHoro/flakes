{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:cf1";
  gravityAddrSingle = last: "${iviDiviPrefix}0::${last}";
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
      localPrefix = "${gravityAddrSingle ""}/${toString prefixLength}";
      # defaultRoute = true;
      inherit gravityTable;

      rait = {
        enable = true;
        transports = [
          { family = "ip4"; sendPort = 59999; mtu = 1420;
            address = "nagisa.jsteward.moe"; }
        ];
      };
    };

    webdav = {
      enable = true;
      environmentFile = config.sops.secrets.webdav-env.path;
      settings = {
        address = "127.0.0.1";
        port = 8080;
        behindProxy = true;
        directory = "/srv/shared";
        permissions = "";
        users = [
          {
            username = "{env}ZOT_USERNAME";
            password = "{env}ZOT_PASSWORD";
            rules = [
              { path = "/zotero"; permissions = "CRUD"; }
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
              proxyPass = "http://127.0.0.1:8080";
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
