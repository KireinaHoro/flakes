{ config, pkgs, ... }:

with pkgs.lib;

let
  ifName = "eth0";
  gravityTable = 3500;
  gravityMark = 333;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "toride";
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

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        address = [ "192.168.0.2/24" ];
        gateway = [ "192.168.0.1" ];
        domains = [ "ethz.ch" ];
        dns = [ "8.8.8.8" "8.8.4.4" ];
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.passwordAuthentication = false;

#    gravity = rec {
#      enable = true;
#      config = raitSecret;
#      netnsAddress = gravityAddr "2";
#      address = gravityAddr "1";
#      subnet = gravityAddr "";
#      inherit prefixLength;
#      inherit gravityTable;
#    };
  };
}
