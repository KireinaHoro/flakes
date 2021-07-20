{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.divi;
in
{
  options.services.divi = {
    enable = mkEnableOption "divi nat64";
    prefix = mkOption {
      type = types.str;
      description = "nat64 prefix";
    };
    address = mkOption {
      type = types.str;
      description = "nat64 address";
    };
    ifName = mkOption {
      type = types.str;
      description = "nat64 output interface name";
    };
  };
  config = mkIf cfg.enable {
    networking.nftables = {
      enable = true;
      ruleset = ''
        table inet divi {
          chain forward {
            type filter hook forward priority 0;
            ip saddr 10.208.0.0/12 tcp flags syn / syn,rst tcp option maxseg size set 1360
            oifname "divi" ip6 saddr != { 2a0c:b641:69c::/48, 2001:470:4c22::/48 } reject
          }
          chain postrouting {
            type nat hook postrouting priority 100;
            oifname "${cfg.ifName}" ip saddr 10.208.0.0/12 masquerade
          }
        }
      '';
    };
    systemd.services.divi = {
      serviceConfig = {
        ExecStart = "${pkgs.tayga}/bin/tayga -d --config ${pkgs.writeText "divi.conf" ''
          tun-device divi
          ipv4-addr 10.208.0.2
          prefix ${cfg.prefix}
          dynamic-pool 10.208.0.0/12
          data-dir /var/spool/tayga
        ''}";
      };
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };
    systemd.network.networks = {
      divi = {
        name = "divi";
        addresses = [
          { addressConfig = { Address = "10.208.0.1/12"; PreferredLifetime = 0; }; }
          { addressConfig = { Address = cfg.address; PreferredLifetime = 0; }; }
        ];
        routes = [
          { routeConfig = { Destination = cfg.prefix; }; }
        ];
      };
    };
  };
}
