{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:cf1";
  gravityAddrSingle = last: "${iviDiviPrefix}0::${last}";
  gravityAddr = last: "${gravityAddrSingle last}/${toString prefixLength}";
  ifName = "enP4p65s0";
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
    hostName = "iori";
    useDHCP = false;
    firewall.enable = false;
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        DHCP = "yes";
        networkConfig = {
          LinkLocalAddressing = "ipv4";
          IPv6AcceptRA = "no";
        };
      };
    };
  };

  services = {
    # vnstat = { enable = true; };

    openssh.passwordAuthentication = false;

/*
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
      virtualHosts = {
        "nagisa.jsteward.moe" = {
          forceSSL = true;
          enableACME = true;
          serverAliases = [ "nagisa.g.jsteward.moe" ];
        };
        "nagisa.g.jsteward.moe" = {
          listen = [ { addr = "nagisa.g.jsteward.moe"; port = 8080; ssl = true; } ]; # only listen in gravity
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
    }; */
  };
}
