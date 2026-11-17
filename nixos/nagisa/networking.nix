{ config, pkgs, ... }:

with pkgs.lib;

let
  my = pkgs.gravityHostByName config.networking.hostName;
  gravityMe = my ({id, ...}: "${pkgs.gravityHomePrefix}:${id}0::1");

  # the VNIC's kernel name depends on the shape (enp0s3 on A1, ens3 on x86
  # paravirtualized, ...); pin it so ranet's localIf stays stable
  ifName = "wan0";
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
    links."10-${ifName}" = {
      matchConfig.Path = "pci-*";
      linkConfig.Name = ifName;
    };
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        # OCI hands out the VNIC's IPv6 address via DHCPv6 and the default
        # route (via the fe80:: VCN router) via RA; both need a link-local.
        DHCP = "yes";
        networkConfig = {
          LinkLocalAddressing = "yes";
          IPv6AcceptRA = true;
        };
        ipv6AcceptRAConfig.DHCPv6Client = "always";
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.settings.PasswordAuthentication = false;

    gravity = {
      enable = true;
      # defaultRoute = true;
      inherit gravityTable;

      ranet = {
        enable = true;
        localIf = ifName;
        endpoints = [
          { address_family = "ip4"; address = "nagisa.jsteward.moe"; }
          { address_family = "ip6"; address = "nagisa.jsteward.moe"; }
        ];
      };

      bird.enable = true;
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
            { addr = "[${gravityMe}]"; port = 8080; ssl = true; }
            { addr = "10.0.0.239"; port = 8080; ssl = true; } # public IPv4 (VNIC private address)
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
