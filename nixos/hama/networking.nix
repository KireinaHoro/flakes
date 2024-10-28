{ config, pkgs, ... }:

with pkgs.lib;

let
  ifName = "enp1s0";
  gravityTable = 3500;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "hama";
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

    gravity = rec {
      enable = true;
      inherit gravityTable;

      rait = {
        enable = true;
        transports = [ { family = "ip4"; sendPort = 57779; mtu = 1420; } ];
      };
      ranet = {
        enable = true;
        localIf = ifName;
        endpoints = [ { address_family = "ip4"; } ];
      };
      bird.enable = true;
    };

    divi = {
      enable = true;
      inherit ifName;
    };

    ivi = {
      enable = true;
    };

    squid = {
      enable = true;
      extraConfig = ''
        acl localnet src 2a0c:b641:69c::/48 10.160.0.0/12 127.0.0.1 ::1

        http_access allow CONNECT localnet
        icp_access allow localnet
        htcp_access allow localnet

        cache_dir aufs /var/cache/squid 500 16 256
        maximum_object_size 65536 KB

        logformat combined  %>a %ui %un [%tl] "%rm %ru HTTP/%rv" %>Hs %<st "%{Referer}>h" "%{User-Agent}>h" %Ss:%Sh
        logfile_rotate 0

        negative_ttl 0
        icp_port 3130
      '';
    };
  };
}
