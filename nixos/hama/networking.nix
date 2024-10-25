{ config, pkgs, ... }:

with pkgs.lib;

let
  # TODO: enable gravity -- allocate prefix, upload keys, etc.
  iviDiviPrefix = "2a0c:b641:69c:ce2";
  ivi4Prefix = "10.172.226";
  ifName = "enp1s0";
  prefixLength = 60;
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
    config = { networkConfig = { IPv6Forwarding = true; }; };
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
      localPrefix = "${iviDiviPrefix}0::/${toString prefixLength}";
      inherit gravityTable;

      rait = {
        enable = true;
        transports = [ { family = "ip4"; sendPort = 57779; mtu = 1420; } ];
      };
      babeld.enable = false;
      bird.enable = true;
    };

    divi = {
      enable = true;
      prefix = "${iviDiviPrefix}4:0:4::/96";
      address = "${iviDiviPrefix}4:0:5:0:3/128";
      inherit ifName;
    };

    ivi = {
      enable = true;
      prefix4 = "${ivi4Prefix}.0";
      prefix6 = "${iviDiviPrefix}5:0:5";
      inherit prefixLength;
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
