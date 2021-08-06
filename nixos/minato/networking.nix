{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:cd0";
  localPrefix = "2a0c:b641:69c:cde0";
  gravityAddr = last: "${iviDiviPrefix}0::${last}/${toString prefixLength}";
  raitSecret = config.sops.secrets.rait.path;
  ifName = "enp0s25";
  prefixLength = 56;

  publicDNS = [ "2001:4860:4860::8888" "8.8.8.8" ];
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "minato";
    useDHCP = false;
    firewall.enable = false;
    proxy = {
      default = "http://kage.g.jsteward.moe:3128";
      noProxy = "127.0.0.1,localhost";
    };
  };

  # FIXME merge masquerade into networkd configuration
  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${localPrefix}::/64 log prefix "Unknown source to WAN: " drop
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
        DHCP = "ipv4";
        vlan = [ "${ifName}.200" ];
        # chinaRoute packets NAT
        networkConfig = {
          IPv6PrivacyExtensions = true;
          # FIXME we cannot use this until systemd v248. ref:
          # IPv6 masquerade: https://github.com/systemd/systemd/commit/b1b4e9204c8260956825e2b9733c95903e215e31
          # nft backend: https://github.com/systemd/systemd/commit/a8af734e75431d676b25afb49ac317036e6825e6
          # IPMasquerade = "ipv4";
        };
        # chinaRoute packets lookup main
        routingPolicyRules = [
          { routingPolicyRuleConfig = { Family = "both"; FirewallMark = 333; }; }
        ];
      };

      "${ifName}.200" = {
        address = [ "10.172.222.254/24" "${localPrefix}::1/64" ];
        networkConfig = {
          DHCPServer = true;
          IPForward = true;
          IPv6SendRA = true;
        };
        dhcpServerConfig = {
          DNS = [ "10.172.222.254" ];
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
          { routingPolicyRuleConfig = {
            From = "${localPrefix}::/64";
            IncomingInterface = "${ifName}.200";
            Table = 3500;
            Priority = 100;
          }; }
          { routingPolicyRuleConfig = { To = "${localPrefix}::/64"; Priority = 100; }; }
        ] ++ map (s: { routingPolicyRuleConfig = { To = s; Table = 3500; }; }) publicDNS;
      };
    };
    netdevs = pkgs.injectNetdevNames {
      "${ifName}.200" = { netdevConfig = { Kind = "vlan"; }; vlanConfig = { Id = 200; }; };
    };
  };

  services = {
    vnstat = { enable = true; };

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
      prefix6 = "${iviDiviPrefix}5:0:5";
      defaultMap = "2a0c:b641:69c:f254:0:4::/96";
      inherit prefixLength;
    };

    chinaRoute = {
      enableV4 = true;
      enableV6 = true;
      prefix6 = "${localPrefix}::/64";
      whitelistV6 = [ "2001:da8:201::/48" ]; # PKU shall still go to seki via gravity
    };

    chinaDNS = {
      enable = true;
      ifName = "${ifName}.200";
      servers = publicDNS;
      chinaServer = "192.168.0.1";
    };
    localResolver = {
      logQueries = true;
      extraConfig = "server=/suki.moe/${config.services.chinaDNS.chinaServer}";
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
