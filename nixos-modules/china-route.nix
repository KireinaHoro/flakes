{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.chinaRoute;
  haveV4Whitelist = length cfg.whitelistV4 != 0;
  haveV6Whitelist = length cfg.whitelistV6 != 0;
in
{
  options.services.chinaRoute = {
    enableV4 = mkEnableOption "mark China IPv4 dst packets with fwmark";
    enableV6 = mkEnableOption "mark China IPv6 dst packets with fwmark";
    prefix6 = mkOption {
      type = types.str;
      description = "nat66 allowed source prefix";
    };
    whitelistV4 = mkOption {
      type = types.listOf types.str;
      description = "prefixes to exclude for v4";
      default = [];
    };
    whitelistV6 = mkOption {
      type = types.listOf types.str;
      description = "prefixes to exclude for v6";
      default = [];
    };
    extraV4 = mkOption {
      type = types.listOf types.str;
      description = "prefixes to include in extra for v4";
      default = [];
    };
    extraV6 = mkOption {
      type = types.listOf types.str;
      description = "prefixes to include in extra for v6";
      default = [];
    };
    fwmark = mkOption {
      type = types.int;
      description = "firewall mark for selected packets";
    };
  };
  config = mkIf (cfg.enableV4 || cfg.enableV6) {
    networking.nftables = {
      enable = true;
      ruleset = ''
        ${if cfg.enableV4 then ''include "${pkgs.chnroute}/chnroute-v4"'' else ""}
        ${if cfg.enableV6 then ''include "${pkgs.chnroute}/chnroute-v6"'' else ""}

        table inet china-route {
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
          ${if cfg.extraV4 != [] then ''
            set extrav4 {
              type ipv4_addr; flags constant, interval
              elements = { ${concatStringsSep ", " cfg.extraV4} }
            }
          '' else ""}
          ${if cfg.extraV6 != [] then ''
            set extrav6 {
              type ipv4_addr; flags constant, interval
              elements = { ${concatStringsSep ", " cfg.extraV6} }
            }
          '' else ""}
          ${if haveV4Whitelist then ''
            set chnv4-nonat {
              type ipv4_addr; flags constant, interval
              elements = { ${toString (map (s: "${s},") cfg.whitelistV4)} }
            }
          '' else ""}
          ${if haveV6Whitelist then ''
            set chnv6-nonat {
              type ipv6_addr; flags constant, interval
              elements = { ${toString (map (s: "${s},") cfg.whitelistV6)} }
            }
          '' else ""}

          chain prerouting {
            type filter hook prerouting priority 0;
            ${if cfg.enableV4 then ''
              ip saddr 10.160.0.0/12 ip daddr @chnv4 ${if haveV4Whitelist then "ip daddr != @chnv4-nonat" else ""} mark set ${toString cfg.fwmark}
              ${if cfg.extraV4 != [] then ''
              ip saddr 10.160.0.0/12 ip daddr @extrav4 mark set ${toString cfg.fwmark}
              '' else ""}
            '' else ""}
            ${if cfg.enableV6 then ''
              ip6 saddr ${cfg.prefix6} ip6 daddr @chnv6 ${if haveV6Whitelist then "ip6 daddr != @chnv6-nonat" else ""} mark set ${toString cfg.fwmark}
              ${if cfg.extraV6 != [] then ''
              ip6 saddr ${cfg.prefix6} ip6 daddr @extrav6 mark set ${toString cfg.fwmark}
              '' else ""}
            '' else ""}
          }
        }
      '';
    };
  };
}
