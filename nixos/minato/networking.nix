{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:cd0";
  localPrefix = "2a0c:b641:69c:cde0";
  gravityAddr = last: "${iviDiviPrefix}0::${last}/56";
  raitSecret = config.sops.secrets.rait.path;
  ifName = "enp0s25";
  prefixLength = 56;

  injectNetworkNames = mapAttrs (name: n: n // { inherit name; });
  injectNetdevNames = mapAttrs (Name: nd: recursiveUpdate nd { netdevConfig = { inherit Name; }; });
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump ];

  networking = {
    hostName = "minato";
    useDHCP = false;
    firewall.enable = false;
  };

  # input hybrid port from MikroTik: untagged for WAN, 200 for gravity local
  systemd.network = {
    networks = injectNetworkNames {
      enp0s25 = {
        DHCP = "ipv4";
        vlan = [ "enp0s25.200" ];
        networkConfig = { IPv6PrivacyExtensions = true; };
        # in combination with chinaLocalNat
        routingPolicyRules = [
          { routingPolicyRuleConfig = { Family = "both"; FirewallMark = 333; }; }
        ];
      };

      "enp0s25.200" = {
        address = [ "10.172.208.254/24" "${localPrefix}::1/64" ];
        networkConfig = {
          DHCPServer = true;
          IPForward = true;
          IPv6SendRA = true;
        };
        dhcpServerConfig = {
          DNS = [ "8.8.8.8" "8.8.4.4" ];
          PoolOffset = 1; # excludes IVI address
        };
        ipv6SendRAConfig = {
          OtherInformation = true;
          EmitDNS = true;
          DNS = [ "2001:4860:4860::8888" "2001:4860:4860::8844" ];
          EmitDomains = false;
        };
        ipv6Prefixes = [ { ipv6PrefixConfig = { Prefix = "${localPrefix}::/64"; }; } ];
        routingPolicyRules = [
          { routingPolicyRuleConfig = { From = "${localPrefix}::/64"; Table = 3500; }; }
        ];
      };
    };
    netdevs = injectNetdevNames {
      "enp0s25.200" = { netdevConfig = { Kind = "vlan"; }; vlanConfig = { Id = 200; }; };
    };
  };

  services = {
    gravity = rec {
      enable = true;
      config = raitSecret;
      netnsAddress = gravityAddr "2";
      address = gravityAddr "1";
      subnet = gravityAddr "";
      group = 54;
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

    chinaLocalNat = {
      enable = true;
      inherit ifName;
      prefix6 = "2a0c:b641:69c::/48";
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
