{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.chinaLocalNat;
in
{
  options.services.chinaLocalNat = {
    enable = mkEnableOption "NAT China IPv4/IPv6 addresses locally";
    ifName = mkOption {
      type = types.str;
      description = "local output interface name";
    };
    prefix6 = mkOption {
      type = types.str;
      description = "nat66 allowed source prefix";
    };
  };
  config = mkIf cfg.enable {
    networking.nftables = {
      enable = true;
      ruleset = ''
        include "${pkgs.chnroute}/chnroute-v4"
        include "${pkgs.chnroute}/chnroute-v6"

        table inet china-local-nat {
          set chnv4 {
            type ipv4_addr; flags constant, interval
            elements = $chnv4_whitelist
          }
          set chnv6 {
            type ipv6_addr; flags constant, interval
            elements = $chnv6_whitelist
          }
          chain forward {
            type filter hook forward priority 0;
            ip saddr 10.160.0.0/12 tcp flags syn / syn,rst tcp option maxseg size set 1360
          }
          chain postrouting {
            type nat hook postrouting priority 100;
            oifname "${cfg.ifName}" ip saddr 10.160.0.0/12 masquerade
            oifname "${cfg.ifName}" ip6 saddr ${cfg.prefix6} masquerade
          }
          chain prerouting {
            type filter hook prerouting priority 0;
            ip saddr 10.160.0.0/12 ip daddr @chnv4 mark set 333
            ip6 saddr ${cfg.prefix6} ip6 daddr @chnv6 mark set 333
          }
        }
      '';
    };
  };
}
