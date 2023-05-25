{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:cb0";
  iviPrefixV4 = "10.172.176"; # 0xcb0
  # using 0xe for ER-X LAN
  localPrefixV4 = "10.172.190"; # 0xcbe
  localPrefix = "2a0c:b641:69c:cbe";
  # could then use e.g. 0xc for remote access
  gravityAddrSingle = last: "${iviDiviPrefix}0::${last}";
  gravityAddr = last: "${gravityAddrSingle last}/${toString prefixLength}";
  ifName = "enP4p65s0";
  prefixLength = 56;
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

  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${localPrefix}::/64 log prefix "Unknown source to WAN: " drop
        }
      }
    '';
  };

  # TODO: extract local gravity gateway to module
  # input hybrid port from ER-X: untagged for WAN, 200 for gravity local
  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        DHCP = "yes";
        vlan = [ "${ifName}.200" ];
        networkConfig = {
          LinkLocalAddressing = "ipv4";
          IPv6AcceptRA = "no";
          IPMasquerade = "ipv4";
        };
      };
      "${ifName}.200" = {
        address = [ "${localPrefixV4}.254/24" "${localPrefix}::1/64" ];
        networkConfig = {
          DHCPServer = true;
          IPForward = true;
          IPv6SendRA = true;
        };
        dhcpServerConfig = {
          # FIXME: run dnsmasq locally so we are standalone
          DNS = [ "10.172.224.1" ]; # shigeru
          # excludes IVI address (.1), ER-X (.253), Gateway (.254), Broadcast (.255)
          PoolOffset = 1;
          PoolSize = 252;
        };
        ipv6SendRAConfig = {
          OtherInformation = true;
          EmitDNS = true;
          DNS = [ "2a0c:b641:69c:ce10::1" ]; # shigeru
          EmitDomains = false;
        };
        ipv6Prefixes = [ { ipv6PrefixConfig = { Prefix = "${localPrefix}::/64"; }; } ];
        routingPolicyRules = [
          { routingPolicyRuleConfig = { To = "${localPrefix}::/64"; Priority = 100; }; }
        ];
      };
    };
    netdevs = pkgs.injectNetdevNames {
      "${ifName}.200" = { netdevConfig = { Kind = "vlan"; }; vlanConfig = { Id = 200; }; };
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
      defaultRoute = true; # we do not have IPv6
      inherit prefixLength;
      inherit gravityTable;
    };

    divi = {
      enable = true;
      prefix = "${iviDiviPrefix}4:0:4::/96";
      address = "${iviDiviPrefix}4:0:5:0:3/128";
      inherit ifName;
    };

    # mark dest China packets with gravityMark
    chinaRoute = {
      fwmark = gravityMark;
      enableV4 = true;
    };

    # packets with gravityMark to minato - back to China
    ivi = {
      enable = true;
      prefix4 = "${iviPrefixV4}.0";
      prefix6 = "${iviDiviPrefix}5:0:5";
      defaultMap = "2a0c:b641:69c:cd04:0:4::/96";
      fwmark = gravityMark;
      inherit prefixLength;
    };

    /* TODO: galleryd
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
