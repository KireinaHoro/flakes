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
  wifiIfName = "wlP2p33s0";
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
    path = with pkgs; [ curl bash ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${./monzoon-login.sh}";
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
          ethzV4Addrs
        );
    };

    smokeping = {
      enable = true;
      owner = "Pengcheng Xu";
      ownerEmail = "i@jsteward.moe";
      webService = false; # we use nginx
      cgiUrl = "https://iori.g.jsteward.moe/smokeping/smokeping.cgi";
      targetConfig = ''
        probe = FPing
        menu = Top
        title = Network Latency Grapher (iori)
        remark = Latency graphs of hosts in and outside of Gravity, observed from iori @ \
          Monzoon Networks, Zürich, Switzerland.  Contact the maintainer (linked at the bottom \
          of page) for more hosts to be included.
        + Gravity
        menu = Gravity
        title = Gravity Hosts
        remark = Selected hosts in Gravity.
        ++ Shigeru
        menu = Shigeru (Zürich, Switzerland)
        title = shigeru @ ETH Zürich (VSOS), Switzerland
        remark = Selected for masquerade exit (also over divi/ivi) for IPv4 ranges of ETH.
        host = shigeru.g.jsteward.moe
        ++ Minato
        menu = Minato (Beijing, China)
        title = minato @ China Unicom, Beijing, China
        remark = Selected for masquerade exit (also over divi/ivi) for IPv4 ranges of Chinese \
          servers according to the APNIC list (github:KireinaHoro/flakes#chnroute).
        host = minato.g.jsteward.moe
        + External
        menu = External Hosts
        title = External Hosts from iori
        remark = Observation of common sites from iori, using the default IPv6 route in the \
          network.  They should give a good estimation of the regular "surfing" experience.
        ++ YouTube
        menu = YouTube
        title = YouTube (youtube.com)
        host = youtube.com
        ++ Google
        menu = Google
        title = Google (google.com)
        host = google.com
        ++ GitHub
        menu = GitHub
        title = GitHub (github.com)
        host = github.com
        ++ ETH-SPCL
        menu = ETH SPCL
        title = ETH SPCL (fpga1)
        host = fpga1.inf.ethz.ch
        ++ NetEase-Music
        menu = NetEase Music
        title = NetEase Music (music.163.com)
        host = music.163.com
      '';
    };

    /* WIP -- Microcode update? */
    /*
    hostapd = {
      enable = false;
      radios = {
        ${wifiIfName} = {
          countryCode = "CH";
          band = "5g";
          channel = 0;
          wifi6.enable = true;
          wifi4.enable = false;
          networks.${wifiIfName} = {
            ssid = "JSteward Tech";
            authentication.saePasswords = [{ password = "8819fe8d-90fa-4137-8467-985238720d97"; }]; # we don't bother with sops for the wifi password
          };
        };
      };
    };
    */

    /* TODO: galleryd */
    nginx = {
      enable = true;
      virtualHosts = {
        "iori.g.jsteward.moe" = {
          forceSSL = true;
          enableACME = true;
          locations = let smokepingHome = config.users.users.${config.services.smokeping.user}.home; in {
            "= /smokeping/smokeping.cgi" = {
              fastcgiParams = {
                SCRIPT_FILENAME = "${smokepingHome}/smokeping.fcgi";
              };
              extraConfig = ''
                fastcgi_intercept_errors on;
                fastcgi_pass unix:${config.services.fcgiwrap.socketAddress};
              '';
            };
            "^~ /smokeping/" = {
              alias = "${smokepingHome}/";
              index = "smokeping.cgi";
            };
            "/" = {
              return = "301 http://$server_name/smokeping/smokeping.cgi";
            };
          };
        };
      };
    };
    fcgiwrap.enable = true;
  };
}
