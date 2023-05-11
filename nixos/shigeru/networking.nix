{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:ce1";
  remoteAccessPrefix = "2a0c:b641:69c:ce1f";
  gravityAddr = last: "${iviDiviPrefix}0::${last}/${toString prefixLength}";
  raitSecret = config.sops.secrets.rait.path;
  ifName = "enp6s18";
  prefixLength = 60;
  publicDNS = [ "2001:4860:4860::8888" "8.8.8.8" ];
  chinaServer = "114.114.114.114";
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

  # FIXME merge masquerade into networkd configuration
  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${iviDiviPrefix}0::/${toString prefixLength} log prefix "Unknown source to WAN: " drop
        }
        chain nat {
          type nat hook postrouting priority 100;
          oifname "${ifName}" masquerade;
        }
      }
      table inet pku-v6 {
        set pkuv6 {
          type ipv6_addr
          flags constant,interval
          elements = { 2001:da8:201::/48,
                       240c:c001::/32 }
        }
        chain prerouting {
          type filter hook prerouting priority 0;
          ip6 saddr ${remoteAccessPrefix}::/64 ip6 daddr @pkuv6 mark set ${toString gravityMark}
        }
      }
    '';
  };

  networking.wireguard.interfaces = {
    remote-access = {
      listenPort = 31675;
      privateKeyFile = config.sops.secrets.remote-access-priv.path;
      peers = [
        { # pixel 4
          publicKey = "xMQLxCBknaGfE5qomFCB3s9uzcvvbbvlU+D1uQtvryY=";
          allowedIPs = [ "10.172.224.2/32" "${remoteAccessPrefix}::2/128" ];
        }
        { # thinkpad
          publicKey = "6zsHjlqznwa2BvieBnSEcJv65ouPY7GVaQiX82Ko22M=";
          allowedIPs = [ "10.172.224.3/32" "${remoteAccessPrefix}::3/128" ];
        }
        { # m1 macbook
          publicKey = "sTmAuGsMebXGsOLGCrowonWEIDDSBnQxTZkAuVzIfU4=";
          allowedIPs = [ "10.172.224.4/32" "${remoteAccessPrefix}::4/128" ];
        }
        { # Jindi iPhone
          publicKey = "i3IJjP1h+z4YtIwY4df2uqUViWBtgL0lK3rGeGRIk3U=";
          allowedIPs = [ "10.172.224.5/32" "${remoteAccessPrefix}::5/128" ];
        }
        { # Jindi Mac
          publicKey = "8NvajLFSN+xSP86v67caUusYgAUqB1dbwTlutCpUjBI=";
          allowedIPs = [ "10.172.224.6/32" "${remoteAccessPrefix}::6/128" ];
        }
        { # iphone 13 mini
          publicKey = "qATZSr/NXq/yPyFX1I7k7F6wJeTMJv5yhSY4aa05n2w=";
          allowedIPs = [ "10.172.224.7/32" "${remoteAccessPrefix}::7/128" ];
        }
        { # desktop
          publicKey = "YdM51psPpxUH7oV5mHmH6POa0h59xwW2cMuAE09deDw=";
          allowedIPs = [ "10.172.224.8/32" "${remoteAccessPrefix}::8/128" ];
        }
      ];
    };
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        address = [ "192.33.91.158/24" "2001:67c:10ec:49c3::19e/118" ];
        gateway = [ "192.33.91.1" ];
        domains = [ "ethz.ch" ];
        dns = [ "129.132.98.12" "129.132.250.2" ];
      };
      remote-access = {
        address = [ "10.172.224.1/24" "${remoteAccessPrefix}::1/64" ];
        routingPolicyRules = [
          # local resolver for China DNS
          { routingPolicyRuleConfig = {
            To = chinaServer;
            Table = gravityTable;
            Priority = 50;
          }; }
          { routingPolicyRuleConfig = {
            From = "${remoteAccessPrefix}::/64";
            IncomingInterface = "remote-access";
            FirewallMark = gravityMark;  # PKU IPv6
            Table = gravityTable;
            Priority = 100;
          }; }
          { routingPolicyRuleConfig = {
            To = "${remoteAccessPrefix}::/64";
            Priority = 100;
          }; }
        ];
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.passwordAuthentication = false;

    chinaRoute = {
      fwmark = gravityMark;
      enableV4 = true;
    };
    chinaDNS = {
      enable = true;
      ifName = "remote-access";
      servers = publicDNS;
      inherit chinaServer;
      accelAppleGoogle = false;
    };
    localResolver = {
      logQueries = true;
      configDirs = [ "${pkgs.hosts-blocklists}/dnsmasq" ];
      # use ETH DNS for internal queries
      extraConfig = ''
        server=/ethz.ch/129.132.98.12
        server=/ethz.ch/129.132.250.2
        server=/youtube.com/
      '';
    };

    gravity = rec {
      enable = true;
      config = raitSecret;
      netnsAddress = gravityAddr "2";
      address = gravityAddr "1";
      subnet = gravityAddr "";
      inherit prefixLength;
      inherit gravityTable;
    };

    divi = {
      enable = true;
      prefix = "${iviDiviPrefix}4:0:4::/96";
      address = "${iviDiviPrefix}4:0:5:0:3/128";
      inherit ifName;
    };

    # default to minato - back to China
    ivi = {
      enable = true;
      prefix4 = "10.172.224.0";
      prefix6 = "${iviDiviPrefix}5:0:5";
      defaultMap = "2a0c:b641:69c:cd04:0:4::/96";
      fwmark = gravityMark;
      inherit prefixLength;
      # map PKU v4 to seki
      extraConfig = concatStringsSep "\n" (map
        ({prefix, len}: pkgs.genIviMap prefix "2a0c:b641:69c:cc04:0:4" len)
        [ { prefix = "162.105.0.0"; len = 16; }
          { prefix = "222.29.0.0"; len = 17; }
          { prefix = "222.29.128.0"; len = 19; }
          { prefix = "115.27.0.0"; len = 16; }
          { prefix = "202.112.7.0"; len = 24; }
          { prefix = "202.112.8.0"; len = 24; } ]
      );
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
