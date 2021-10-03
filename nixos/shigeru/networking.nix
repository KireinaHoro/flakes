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
          publicKey = "q4zeQsdAgfMu+z8F0QlmtlcUz75VqSONIq+Mz6Ja40U=";
          allowedIPs = [ "10.172.224.3/32" "${remoteAccessPrefix}::3/128" ];
        }
        { # m1 macbook
          publicKey = "sTmAuGsMebXGsOLGCrowonWEIDDSBnQxTZkAuVzIfU4=";
          allowedIPs = [ "10.172.224.4/32" "${remoteAccessPrefix}::4/128" ];
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
            Table = 3500;
            Priority = 50;
          }; }
          { routingPolicyRuleConfig = {
            From = "${remoteAccessPrefix}::/64";
            IncomingInterface = "remote-access";
            FirewallMark = 333;  # only redirect China-destined packets
            Table = 3500;
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

    chinaRoute.enableV4 = true;
    chinaDNS = {
      enable = true;
      ifName = "remote-access";
      servers = publicDNS;
      inherit chinaServer;
    };
    localResolver = {
      logQueries = true;
      configDirs = [ "${pkgs.hosts-blocklists}/dnsmasq" ];
    };

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

    # default to minato - back to China
    ivi = {
      enable = true;
      prefix4 = "10.172.224.0";
      prefix6 = "${iviDiviPrefix}5:0:5";
      defaultMap = "2a0c:b641:69c:cd04:0:4::/96";
      fwmark = 333;
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
  };
}
