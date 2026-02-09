{ config, pkgs, ... }:

with pkgs.lib;

let
  my = pkgs.gravityHostByName config.networking.hostName;

  localPrefix = "2a0c:b641:69c:cde0";
  local4Prefix = "10.172.222";
  remoteAccessPrefix = "2a0c:b641:69c:cdc0";
  remoteAccess4Prefix = "10.172.220";
  remoteAccessPort = 31675;
  ifName = "enp0s25";

  publicDNS = [ "2001:4860:4860::8888" "8.8.8.8" ];

  gravityMark = 333;
  gravityTable = 3500;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "minato";
    useDHCP = false;
    firewall.enable = false;
    proxy = {
      default = "http://shigeru.g.jsteward.moe:3128";
      noProxy = "127.0.0.1,localhost,tsinghua.edu.cn";
    };
  };

  networking.nftables = {
    ruleset = ''
      table inet gravity-access {
        chain filter {
          type filter hook forward priority 100;
          meta nfproto ipv4 tcp flags syn / syn,rst tcp option maxseg size set 1360;
          meta nfproto ipv6 tcp flags syn / syn,rst tcp option maxseg size set 1340;
        }
      }

      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${localPrefix}::/64 log prefix "Unknown source to WAN: " drop
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
        networkConfig = {
          IPv6AcceptRA = true;
          IPv6PrivacyExtensions = "prefer-public";
        };
        # chinaRoute packets lookup main
        routingPolicyRules = [
          { Family = "both"; FirewallMark = gravityMark; Priority = 60; }
        ];
      };

      "${ifName}.200" = {
        address = [ "${local4Prefix}.254/24" "${localPrefix}::1/64" ];
        linkConfig = { RequiredForOnline = false; };
        networkConfig = {
          DHCPServer = true;
          IPv6SendRA = true;
          IPMasquerade = "ipv4";
        };
        dhcpServerConfig = {
          DNS = [ "${local4Prefix}.254" ];
          PoolOffset = 1; # excludes IVI address
        };
        ipv6SendRAConfig = {
          OtherInformation = true;
          EmitDNS = true;
          DNS = [ "${localPrefix}::1" ];
          EmitDomains = false;
        };
        ipv6Prefixes = [ { Prefix = "${localPrefix}::/64"; } ];
        routingPolicyRules = [
          {
            From = "${localPrefix}::/64";
            IncomingInterface = "${ifName}.200";
            Table = gravityTable;
            Priority = 100;
          }
          { To = "${localPrefix}::/64"; Priority = 100; }
        ] ++ map (s: { To = s; Table = gravityTable; }) publicDNS;
      };
      remote-access = {
        address = [ "${remoteAccess4Prefix}.1/24" "${remoteAccessPrefix}::1/64" ];
        linkConfig = { RequiredForOnline = false; };
        networkConfig = { IPMasquerade = "ipv4"; };
        routingPolicyRules = [
          {
            From = "${remoteAccessPrefix}::/64";
            IncomingInterface = "remote-access";
            Table = gravityTable;
            Priority = 100;
          }
          { To = "${remoteAccessPrefix}::/64"; Priority = 100; }
        ];
      };
    };
    netdevs = pkgs.injectNetdevNames {
      remote-access = {
        netdevConfig = { Kind = "wireguard"; };
        wireguardConfig = {
          ListenPort = remoteAccessPort;
          PrivateKeyFile = config.sops.secrets.remote-access-priv.path;
        };
        wireguardPeers = [
          { # pixel 4
            PublicKey = "zXU3IYwRdNnjEitP/WjS+v8q7KnPbYumwx3qEw0uGzM=";
            AllowedIPs = [ "${remoteAccess4Prefix}.2/32" "${remoteAccessPrefix}::2/128" ];
          }
          { # thinkpad
            PublicKey = "q4zeQsdAgfMu+z8F0QlmtlcUz75VqSONIq+Mz6Ja40U=";
            AllowedIPs = [ "${remoteAccess4Prefix}.3/32" "${remoteAccessPrefix}::3/128" ];
          }
          { # m1 macbook
            PublicKey = "a713fmoT2Fbjyn097mgr2o33PhIMyrYfxU4eRjfLZH4=";
            AllowedIPs = [ "${remoteAccess4Prefix}.4/32" "${remoteAccessPrefix}::4/128" ];
          }
          { # iphone
            PublicKey = "VqHfNMuAylcvkwWfY5nXqdowOBzTRyOIwGm5G3CeJlA=";
            AllowedIPs = [ "${remoteAccess4Prefix}.5/32" "${remoteAccessPrefix}::5/128" ];
          }
          { # ushi device 1
            PublicKey = "AOje2nnk1FDEyB4UvX3WeT2x33x5uVnuGdAqMJOZ8Ws=";
            AllowedIPs = [ "${remoteAccess4Prefix}.6/32" "${remoteAccessPrefix}::6/128" ];
          }
          { # ushi device 2
            PublicKey = "wKGCJX6z7NanHx4PZi0SAT9ugvdJvBVqwHXQG/ogLl8=";
            AllowedIPs = [ "${remoteAccess4Prefix}.7/32" "${remoteAccessPrefix}::7/128" ];
          }
        ];
      };
      "${ifName}.200" = { netdevConfig = { Kind = "vlan"; }; vlanConfig = { Id = 200; }; };
    };
  };

  services = {
    vnstat = { enable = true; };

    gravity = rec {
      enable = true;
      inherit gravityTable;

      rait = {
        enable = true;
        transports = [
          { family = "ip4"; sendPort = 53333; mtu = 1420; }
          { family = "ip6"; sendPort = 54444; mtu = 1400;
            address = "minato.jsteward.moe"; }
        ];
      };
      ranet = {
        enable = true;
        localIf = ifName;
        endpoints = [
          { address_family = "ip4"; }
          { address_family = "ip6"; address = "minato.jsteward.moe"; }
        ];
      };

      bird.enable = true;
    };

    divi = {
      enable = true;
      inherit ifName;
    };

    ivi = {
      enable = true;
      default = "nick_sin";
      # map ETH to shigeru
      extraConfig = concatStringsSep "\n" (map
        (pkgs.gravityHostByName "shigeru" pkgs.gravityHostToIviDestMap)
        pkgs.ethzV4Addrs
      );
    };

    chinaRoute = {
      enableV4 = true;
      enableV6 = true;
      prefix6 = "${localPrefix}::/64";
      fwmark = gravityMark;
    };

    chinaDNS = {
      enable = true;
      servers = publicDNS;
      chinaServer = "192.168.0.1";
    };
    localResolver = {
      listenAddrs = [ "${remoteAccess4Prefix}.1" "${local4Prefix}.254" ];
      logQueries = true;
      configDirs = [ "${pkgs.hosts-blocklists}/dnsmasq" ];
      servers = [
        "/suki.moe/${config.services.chinaDNS.chinaServer}"
        "/ethz.ch/129.132.98.12"
        "/ethz.ch/129.132.250.2"
        "/gravity/sin0.nichi.link"
        "/gravity/sea0.nichi.link"
      ];
    };

    squid = {
      enable = true;
      configText = ''
        #
        # Recommended minimum configuration (3.5):
        #

        # Example rule allowing access from your local networks.
        # Adapt to list your (internal) IP networks from where browsing
        # should be allowed
        acl localnet src 10.0.0.0/8     # RFC 1918 possible internal network
        acl localnet src 172.16.0.0/12  # RFC 1918 possible internal network
        acl localnet src 192.168.0.0/16 # RFC 1918 possible internal network
        acl localnet src 169.254.0.0/16 # RFC 3927 link-local (directly plugged) machines
        acl localnet src fc00::/7       # RFC 4193 local private network range
        acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines

        acl SSL_ports port 443          # https
        acl Safe_ports port 80          # http
        acl Safe_ports port 21          # ftp
        acl Safe_ports port 443         # https
        acl Safe_ports port 70          # gopher
        acl Safe_ports port 210         # wais
        acl Safe_ports port 1025-65535  # unregistered ports
        acl Safe_ports port 280         # http-mgmt
        acl Safe_ports port 488         # gss-http
        acl Safe_ports port 591         # filemaker
        acl Safe_ports port 777         # multiling http
        acl CONNECT method CONNECT

        #
        # Recommended minimum Access Permission configuration:
        #
        # Deny requests to certain unsafe ports
        http_access deny !Safe_ports

        # update with: curl -X POST <redacted> | jq | grep URL | cut -d ':' -f 4 | cut -d '"' -f 1 | tr -s '\n'
        acl Suki_ports port 8443
        acl Suki_ports port 10025
        acl Suki_ports port 39992
        acl Suki_ports port 39901

        http_access allow CONNECT

        # http_access allow CONNECT Suki_ports

        # Deny CONNECT to other than secure SSL ports
        # http_access deny CONNECT !SSL_ports

        # Only allow cachemgr access from localhost
        http_access allow localhost manager
        http_access deny manager

        # We strongly recommend the following be uncommented to protect innocent
        # web applications running on the proxy server who think the only
        # one who can access services on "localhost" is a local user
        http_access deny to_localhost

        # Application logs to syslog, access and store logs have specific files
        cache_log       syslog
        access_log      stdio:/var/log/squid/access.log
        cache_store_log stdio:/var/log/squid/store.log

        # Required by systemd service
        pid_filename    /run/squid.pid

        # Run as user and group squid
        cache_effective_user squid squid

        #
        # INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS
        #
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


        # Example rule allowing access from your local networks.
        # Adapt localnet in the ACL section to list your (internal) IP networks
        # from where browsing should be allowed
        http_access allow localnet
        http_access allow localhost

        # And finally deny all other access to this proxy
        http_access deny all

        # Squid normally listens to port 3128
        http_port 3128

        # Leave coredumps in the first cache dir
        coredump_dir /var/cache/squid

        #
        # Add any of your own refresh_pattern entries above these.
        #
        refresh_pattern ^ftp:           1440    20%     10080
        refresh_pattern ^gopher:        1440    0%      1440
        refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
        refresh_pattern .               0       20%     4320
      '';
    };

    inadyn = {
      enable = true;
      configFile = config.sops.secrets.inadyn-cfg.path;
    };
  };

  systemd.services = {
    "inadyn".serviceConfig = {
      # disable IPv4 access for inadyn
      RestrictAddressFamilies = mkForce "AF_INET6 AF_NETLINK";
    };
    "forward-wg-ipv4" = {
      serviceConfig = let
        bash = "${pkgs.bash}/bin/bash";
        socat = "${pkgs.socat}/bin/socat";
      in {
        ExecStartPre = [
          # send a dummy packet
          "${bash} -c \"echo a | ${socat} -T6 -d - udp4:$HOST:$PORT,reuseaddr,sourceport=4444\""
        ];
        ExecStart = "${bash} -c \"${socat} -4 -d -T6 udp4:127.0.0.1:${toString remoteAccessPort} udp4:$HOST:$PORT,keepalive,reuseaddr,sourceport=4444\"";
        EnvironmentFile = config.sops.secrets.forward_wg_ipv4.path;
        Restart = "always";
        RestartSec = 1;
      };
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
