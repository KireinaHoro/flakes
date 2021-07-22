{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.chinaLocalNat;
in
{
  options.services.chinaLocalNat = {
    enableV4 = mkEnableOption "NAT China IPv4 addresses locally";
    enableV6 = mkEnableOption "NAT China IPv6 addresses locally";
    ifName = mkOption {
      type = types.str;
      description = "local output interface name";
    };
    prefix6 = mkOption {
      type = types.str;
      description = "nat66 allowed source prefix";
    };
  };
  config = mkIf (cfg.enableV4 || cfg.enableV6) {
    networking.nftables = {
      enable = true;
      ruleset = ''
        ${if cfg.enableV4 then ''include "${pkgs.chnroute}/chnroute-v4"'' else ""}
        ${if cfg.enableV6 then ''include "${pkgs.chnroute}/chnroute-v6"'' else ""}

        table inet china-local-nat {
          ${if cfg.enableV4 then ''
            set chnv4 {
              type ipv4_addr; flags constant, interval
              elements = $chnv4_whitelist
            }
          '' else ""}
          ${if cfg.enableV6 then ''
            set chnv6 {
              type ipv6_addr; flags constant, interval
              elements = $chnv6_whitelist
            }
          '' else ""}
          chain forward {
            type filter hook forward priority 0;
            ip saddr 10.160.0.0/12 tcp flags syn / syn,rst tcp option maxseg size set 1360
          }
          chain postrouting {
            type nat hook postrouting priority 100;
            ${if cfg.enableV4 then ''oifname "${cfg.ifName}" ip saddr 10.160.0.0/12 masquerade'' else ""}
            ${if cfg.enableV6 then ''oifname "${cfg.ifName}" ip6 saddr ${cfg.prefix6} masquerade'' else ""}
          }
          chain prerouting {
            type filter hook prerouting priority 0;
            ${if cfg.enableV4 then ''ip saddr 10.160.0.0/12 ip daddr @chnv4 mark set 333'' else ""}
            ${if cfg.enableV6 then ''ip6 saddr ${cfg.prefix6} ip6 daddr @chnv6 mark set 333'' else ""}
          }
        }
      '';
    };
  };
}
