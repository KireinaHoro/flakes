{ config, pkgs, ... }:

with pkgs.lib;

let
  my = pkgs.gravityHostByName config.networking.hostName;

  ivi4Prefix = removeSuffix ".0" (my pkgs.gravityHostToIviPrefix4).prefix;
  remoteAccessPrefix = my ({id, ...}: "${pkgs.gravityHomePrefix}:${id}f");
  ifName = "enp6s18";
  publicDNS = [ "2001:4860:4860::8888" "8.8.8.8" ];
  chinaServer = "114.114.114.114";

  gravityPrefix = my pkgs.gravityHostToPrefix;
  gravityTable = 3500;
  gravityMark = 333;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "shigeru";
    useDHCP = false;
    firewall.enable = false;
  };

  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${gravityPrefix} log prefix "Unknown source to WAN: " drop
        }
      }
    '';
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        address = [ "192.33.91.158/24" "2001:67c:10ec:49c3::19e/118" ];
        gateway = [ "192.33.91.1" "2001:67c:10ec:49c3::1" ];
        domains = [ "ethz.ch" ];
        dns = [ "129.132.98.12" "129.132.250.2" ];
      };
      remote-access = {
        address = [ "${ivi4Prefix}.1/24" "${remoteAccessPrefix}::1/64" ];
        linkConfig = { RequiredForOnline = false; };
        networkConfig = { IPMasquerade = "ipv4"; };
        routingPolicyRules = [
          {
            # we only feed v6 that go to China into Gravity
            # other stuff will get masqueraded locally
            From = "${remoteAccessPrefix}::/64";
            IncomingInterface = "remote-access";
            FirewallMark = gravityMark;
            Table = gravityTable;
            Priority = 100;
          }
          {
            To = "${remoteAccessPrefix}::/64";
            Priority = 100;
          }
        ];
      };
    };
    netdevs = pkgs.injectNetdevNames {
      remote-access = {
        netdevConfig = { Kind = "wireguard"; };
        wireguardConfig = {
          ListenPort = 31675;
          PrivateKeyFile = config.sops.secrets.remote-access-priv.path;
        };
        wireguardPeers = [
          { # pixel 4
            PublicKey = "xMQLxCBknaGfE5qomFCB3s9uzcvvbbvlU+D1uQtvryY=";
            AllowedIPs = [ "${ivi4Prefix}.2/32" "${remoteAccessPrefix}::2/128" ];
          }
          { # thinkpad t470p
            PublicKey = "6zsHjlqznwa2BvieBnSEcJv65ouPY7GVaQiX82Ko22M=";
            AllowedIPs = [ "${ivi4Prefix}.3/32" "${remoteAccessPrefix}::3/128" ];
          }
          { # m1 macbook air
            PublicKey = "sTmAuGsMebXGsOLGCrowonWEIDDSBnQxTZkAuVzIfU4=";
            AllowedIPs = [ "${ivi4Prefix}.4/32" "${remoteAccessPrefix}::4/128" ];
          }
          { # iphone 13 mini
            PublicKey = "qATZSr/NXq/yPyFX1I7k7F6wJeTMJv5yhSY4aa05n2w=";
            AllowedIPs = [ "${ivi4Prefix}.7/32" "${remoteAccessPrefix}::7/128" ];
          }
          { # desktop in Zurich home
            PublicKey = "YdM51psPpxUH7oV5mHmH6POa0h59xwW2cMuAE09deDw=";
            AllowedIPs = [ "${ivi4Prefix}.8/32" "${remoteAccessPrefix}::8/128" ];
          }
        ];
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.settings.PasswordAuthentication = false;

    chinaRoute = {
      fwmark = gravityMark;
      enableV4 = true;
    };
    chinaDNS = {
      enable = true;
      servers = publicDNS;
      inherit chinaServer;
      accelAppleGoogle = false;
    };
    localResolver = {
      logQueries = true;
      listenAddrs = [ "${ivi4Prefix}.1" ];
      configDirs = [ "${pkgs.hosts-blocklists}/dnsmasq" ];
      # use ETH DNS for internal queries
      servers = [
        "/ethz.ch/129.132.98.12"
        "/ethz.ch/129.132.250.2"
        "/gravity/sin0.nichi.link"
        "/gravity/sea0.nichi.link"
      ];
      addresses = [
        # block netease ipv6 for cloud music
        "/163.com/::"
        "/netease.com/::"
      ];
    };

    gravity = rec {
      enable = true;
      inherit gravityTable;
      extraRoutePolicies = [
        # chinese recursive for China DNS
        {
          To = chinaServer;
          Table = gravityTable;
          Priority = 50;
        }
      ];

      rait = {
        enable = true;
        transports = [
          { family = "ip4"; sendPort = 57777; mtu = 1420;
            address = "shigeru.jsteward.moe"; }
          { family = "ip6"; sendPort = 58888; mtu = 1400;
            address = "shigeru.jsteward.moe"; }
        ];
      };
      ranet = {
        enable = true;
        localIf = ifName;
        endpoints = [
          { address_family = "ip4"; address = "shigeru.jsteward.moe"; }
          { address_family = "ip6"; address = "shigeru.jsteward.moe"; }
        ];
      };

      bird.enable = true;
    };

    divi = {
      enable = true;
      inherit ifName;
    };

    # default to minato - back to China
    ivi = {
      enable = true;
      default = "minato";
      fwmark = gravityMark;
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
