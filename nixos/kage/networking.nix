{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:ce0";
  gravityAddr = last: "${iviDiviPrefix}0::${last}/${prefixLength}";
  raitSecret = config.sops.secrets.rait.path;
  ifName = "ens3";
  prefixLength = 60;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "kage";
    useDHCP = false;
    firewall.enable = false;
  };

  # FIXME merge masquerade into networkd configuration
  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${iviDiviPrefix}0::/${prefixLength} log prefix "Unknown source to WAN: " drop
        }
        chain nat {
          type nat hook postrouting priority 100;
          oifname "${ifName}" masquerade;
        }
      }
    '';
  };

  # input hybrid port from MikroTik: untagged for WAN, 200 for gravity local
  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        DHCP = "yes";
        networkConfig = {
          IPv6PrivacyExtensions = true;
          # FIXME we cannot use this until systemd v248. ref:
          # IPv6 masquerade: https://github.com/systemd/systemd/commit/b1b4e9204c8260956825e2b9733c95903e215e31
          # nft backend: https://github.com/systemd/systemd/commit/a8af734e75431d676b25afb49ac317036e6825e6
          # IPMasquerade = "ipv4";
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
    };

    divi = {
      enable = true;
      prefix = "${iviDiviPrefix}4:0:4::/96";
      address = "${iviDiviPrefix}4:0:5:0:3/128";
      inherit ifName;
    };

    ivi = {
      enable = true;
      prefix4 = "10.172.208.0";
      prefix6 = "2a0c:b641:69c:cd05:0:5";
      defaultMap = "2a0c:b641:69c:f254:0:4::/96";
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
    */
  };
}
