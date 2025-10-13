{ config, pkgs, ... }:

with pkgs.lib;

let
  # using 0xe for ER-X LAN
  localPrefixV4 = "10.172.190"; # 0xcbe
  localPrefixV6 = "2a0c:b641:69c:cbe0";
  localGatewayV4 = "${localPrefixV4}.254";
  localGatewayV6 = "${localPrefixV6}::1";
  ifName = "enP4p65s0";
  wifiIfName = "wlP2p33s0";
  publicDNS = [ "2001:4860:4860::8888" "8.8.8.8" ];
  hostsToGravity = [
    # Chinese DNS server
    "114.114.114.114"
    # ETH DNS servers -- we shouldn't keep pinging these...
    "129.132.98.12" "129.132.250.2"
    # ETH workstation (sgd-dalcoi5-06.ethz.ch)
    "129.132.102.8"
  ];
  gravityTable = 3500;
  gravityMark = 333;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  # allow nginx to access smokeping home
  users.groups.smokeping.members = [ "nginx" ];

  networking = {
    hostName = "iori";
    useDHCP = false;
    firewall.enable = false;
  };

  networking.wireless = {
    enable = false;
    interfaces = [ wifiIfName ];
    secretsFile = config.sops.secrets.wireless-secrets.path;
    networks."FRITZ!Box 4040 ON".pskRaw = "ext:psk_home";
  };

  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${localPrefixV6}::/64 log prefix "Unknown source to WAN: " drop
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
          IPv6AcceptRA = true;
          LinkLocalAddressing = "ipv6";
        };
      };
      "${ifName}.200" = {
        linkConfig.RequiredForOnline = false;
        networkConfig.Bridge = "local-devs";
      };
      ${wifiIfName} = {
        enable = false;
        DHCP = "yes";
        networkConfig.IgnoreCarrierLoss = "3s";
      };
      local-devs = {
        address = [ "${localGatewayV4}/24" "${localGatewayV6}/64" ];
        linkConfig.RequiredForOnline = false;
        networkConfig = {
          DHCPServer = true;
          IPv6SendRA = true;
          IPMasquerade = "ipv4";
        };
        dhcpServerConfig = {
          DNS = [ "${localGatewayV4}" ];
          # excludes IVI address (.1), ER-X (.253), Gateway (.254), Broadcast (.255)
          PoolOffset = 1;
          PoolSize = 252;
        };
        ipv6SendRAConfig = {
          OtherInformation = true;
          EmitDNS = false;
          EmitDomains = false;
        };
        ipv6Prefixes = [ { Prefix = "${localPrefixV6}::/64"; } ];
        routingPolicyRules = [
          {
            # route return traffic back to local devices
            # out traffic routed by default route
            To = "${localPrefixV6}::/64";
            Priority = 100;
          }
        ];
      };
    };
    netdevs = pkgs.injectNetdevNames {
      "${ifName}.200" = { netdevConfig = { Kind = "vlan"; }; vlanConfig = { Id = 200; }; };
      "local-devs" = { netdevConfig.Kind = "bridge"; };
    };
  };

  # same as fping setuid as in smokeping
  security.wrappers."fping-gravity" = {
    setuid = true;
    owner = "root";
    group = "root";
    source = pkgs.writeScript "fping-gravity" ''
      #!${pkgs.bash}/bin/bash -p
      ${pkgs.iproute2}/bin/ip netns exec gravity ${pkgs.fping}/bin/fping "$@"
    '';
  };

  services = {
    vnstat = { enable = true; };
    openssh.settings.PasswordAuthentication = false;

    gravity = {
      enable = true;
      inherit gravityTable;
      # upstream recursive DNS into gravity
      extraRoutePolicies = map (s: {
        To = s;
        Table = gravityTable;
        Priority = 50;
      }) hostsToGravity;

      rait = {
        enable = true;
        transports = [
          { family = "ip4"; sendPort = 57778; mtu = 1420; }
          { family = "ip6"; sendPort = 57779; mtu = 1400;
            address = "iori.jsteward.moe"; }
        ];
      };
      ranet = {
        enable = true;
        localIf = ifName;
        endpoints = [
          { address_family = "ip4"; }
          { address_family = "ip6"; address = "iori.jsteward.moe"; }
        ];
      };

      bird.enable = true;
    };

    divi = {
      enable = true;
      inherit ifName;
    };

    # mark dest China and ETH packets with gravityMark
    chinaRoute = {
      fwmark = gravityMark;
      enableV4 = true;
      extraV4 = map ({ prefix, len }: "${prefix}/${toString len}") pkgs.ethzV4Addrs;
    };
    chinaDNS = {
      enable = true;
      servers = publicDNS;
      chinaServer = head hostsToGravity;
      accelAppleGoogle = false;
    };
    localResolver = {
      logQueries = true;
      listenAddrs = [ "${localGatewayV4}" ];
      configDirs = [ "${pkgs.hosts-blocklists}/dnsmasq" ];
      servers = [
        "/ethz.ch/129.132.98.12"
        "/ethz.ch/129.132.250.2"
        "/gravity/sin0.nichi.link"
        "/gravity/sea0.nichi.link"
      ];
    };

    ivi = {
      enable = true;
      # accept packets with gravityMark
      fwmark = gravityMark;
      # default map to minato - back to China
      default = "minato";
      # map ETH to shigeru
      extraConfig = concatStringsSep "\n" (map
        (pkgs.gravityHostByName "shigeru" pkgs.gravityHostToIviDestMap)
        pkgs.ethzV4Addrs
      );
    };

    smokeping = {
      enable = true;
      owner = "Pengcheng Xu";
      ownerEmail = "i@jsteward.moe";
      webService = false; # we use nginx
      cgiUrl = "https://iori.g.jsteward.moe/smokeping/smokeping.cgi";
      databaseConfig = ''
        step     = 60
        pings    = 20
        # consfn mrhb steps total
        AVERAGE  0.5   1  5040
        AVERAGE  0.5  12  21600
            MIN  0.5  12  21600
            MAX  0.5  12  21600
        AVERAGE  0.5 144   3600
            MAX  0.5 144   3600
            MIN  0.5 144   3600
      '';
      probeConfig = ''
        + FPing
        binary = ${config.security.wrapperDir}/fping
        packetsize = 1000
        ++ FP4
        protocol = 4
        ++ FP6
        protocol = 6
        ++ GP6
        protocol = 6
        binary = ${config.security.wrapperDir}/fping-gravity
      '';
      targetConfig = with pkgs; let
        gravityHostToTarget = h@{name, remarks ? "(no remarks)", ...}: let
          prefix = gravityHostToPrefix h;
          parts = splitString "/" prefix;
          host = "${elemAt parts 0}1";
        in ''
          ++ ${name}
          probe = GP6
          menu = ${name}
          title = ${name} @ ${remarks}
          remark = Gravity host ${name} (${gravityHostToPrefix h})
          host = ${host}
        '';
        externalHostsV6 = [
          { name = "YouTube"; host = "youtube.com"; }
          { name = "Google"; host = "google.com"; }
        ];
        externalHostsV4 = [
          { name = "EnzianGateway"; host = "enzian-gateway.inf.ethz.ch"; }
          { name = "ShigeruVSOS"; host = "shigeru.vsos.ethz.ch"; }
          { name = "GitHub"; host = "github.com"; }
          { name = "FRITZ!Box"; host = "192.168.178.1"; }
        ] ++ externalHostsV6;
        externalHostsThroughGravity = [
          { name = "114DNS"; host = "114.114.114.114"; }
          { name = "STF-Workstation"; host = "sgd-dalcoi5-06.ethz.ch"; }
        ];
        externalHostToTarget = probe: {name, host}: ''
          ++ ${name}
          probe = ${probe}
          menu = ${name}
          title = ${name} (${host})
          host = ${host}
        '';
      in ''
        probe = FP4
        menu = Top
        title = Network Latency Grapher (iori)
        remark = Latency graphs of hosts in and outside of Gravity, observed from iori @ \
          iWay, Zürich, Switzerland.  Contact the maintainer (linked at the bottom \
          of page) for more hosts to be included.
        + Gravity
        menu = Gravity
        title = Gravity Hosts
        remark = Selected hosts in Gravity.
        ${concatStrings (map gravityHostToTarget gravityHosts)}
        + External
        menu = External Hosts (v4)
        title = External Hosts from iori over IPv4
        remark = Observation of common IPv4 sites from iori, which uses the provider's default \
          route.  They should give a good estimation of the external provider's connectivity.
        ${concatStringsSep "\n" (map (externalHostToTarget "FP4") externalHostsV4)}
        + Gravity-DefaultRoute
        menu = External Hosts (v6 Gravity)
        title = External Hosts from iori over default route from Gravity
        remark = Observation of common IPv6 sites from iori, which uses the default route in \
          Gravity.  As most of major websites have IPv6 access already, they should give a good \
          estimation of the surfing experience of a client on iori.
        ${concatStrings (map (externalHostToTarget "FP6") externalHostsV6)}
        + Gravity-IVI
        menu = IVI Hosts (v4 Gravity)
        title = IPv4 hosts as reached over IVI.  ETH hosts go to shigeru, while the Chinese DNS \
          go to minato.
        ${concatStrings (map (externalHostToTarget "FP4") externalHostsThroughGravity)}
      '';
    };

    squid = {
      enable = true;
      extraConfig = ''
        acl localnet src 2a0c:b641:69c::/48 10.160.0.0/12 127.0.0.1 ::1

        http_access allow CONNECT
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
                fastcgi_pass unix:${config.services.fcgiwrap.instances.nginx.socket.address};
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
    fcgiwrap.instances.nginx = {
      process.user = config.services.smokeping.user;
      process.group = config.services.smokeping.user;
      socket = { inherit (config.services.nginx) user group; };
    };
  };
}
