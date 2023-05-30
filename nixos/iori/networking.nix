{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:cb0";
  iviPrefixV4 = "10.172.176"; # 0xcb0
  # using 0xe for ER-X LAN
  localPrefixV4 = "10.172.190"; # 0xcbe
  localPrefix = "2a0c:b641:69c:cbe0";
  # could then use e.g. 0xc for remote access
  gravityAddrSingle = last: "${iviDiviPrefix}0::${last}";
  gravityAddr = last: "${gravityAddrSingle last}/${toString prefixLength}";
  ifName = "enP4p65s0";
  prefixLength = 56;
  gravityTable = 3500;
  gravityMark = 333;
  ethzV4Addrs = [
    { prefix = "82.130.64.0"; len = 18; }
    { prefix = "192.33.96.0"; len = 21; }
    { prefix = "192.33.92.0"; len = 22; }
    { prefix = "192.33.91.0"; len = 24; }
    { prefix = "192.33.90.0"; len = 24; }
    { prefix = "192.33.87.0"; len = 24; }
    { prefix = "192.33.110.0"; len = 24; }
    { prefix = "192.33.108.0"; len = 23; }
    { prefix = "192.33.104.0"; len = 22; }
    { prefix = "148.187.192.0"; len = 19; }
    { prefix = "129.132.0.0"; len = 16; }
  ];
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
          # XXX: using shigeru for ETHZ domains
          DNS = [ "10.172.224.1" ]; # shigeru
          # excludes IVI address (.1), ER-X (.253), Gateway (.254), Broadcast (.255)
          PoolOffset = 1;
          PoolSize = 252;
        };
        ipv6SendRAConfig = {
          OtherInformation = true;
          EmitDNS = false;
          # DNS = [ "2a0c:b641:69c:ce10::1" ];
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

  # automatic login to Monzoon Networks
  systemd.timers."monzoon-login" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "monzoon-login.service";
    };
  };
  systemd.services."monzoon-login" = {
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${pkgs.bash}/bin/bash ${./monzoon-login.sh}";
      Environment = "CURL=${pkgs.curl}/bin/curl";
      EnvironmentFile = config.sops.secrets.monzoon_env.path;
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

    # mark dest China and ETH packets with gravityMark
    chinaRoute = {
      fwmark = gravityMark;
      enableV4 = true;
      extraV4 = map ({ prefix, len }: "${prefix}/${toString len}") ethzV4Addrs;
    };

    # packets with gravityMark to minato - back to China
    ivi = {
      enable = true;
      prefix4 = "${iviPrefixV4}.0";
      prefix6 = "${iviDiviPrefix}5:0:5";
      defaultMap = "2a0c:b641:69c:cd04:0:4::/96";
      fwmark = gravityMark;
      inherit prefixLength;
      # map ETH
      extraConfig = concatStringsSep "\n" (map
        ({ prefix, len }: pkgs.genIviMap prefix "2a0c:b641:69c:ce14:0:4" len) # shigeru
          # ETHZ
          (ethzV4Addrs ++
          # shigeru's own IVI address
          [ { prefix = "10.172.224.0"; len = 24; } ])
        );
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
