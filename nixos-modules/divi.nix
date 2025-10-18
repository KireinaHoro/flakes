{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.divi;
  my = pkgs.gravityHostByName config.networking.hostName;
  pre = with my pkgs.gravityHostToDiviPrefix; "${prefix}/${toString len}";
  address = my ({id, ...}:
    "${pkgs.gravityHomePrefix}:${id}4:0:5:0:3/128");
in
{
  options.services.divi = {
    enable = mkEnableOption "divi nat64";
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
            oifname "divi" ip6 saddr != { 2a0c:b641:69c::/48, 2001:470:4c22::/48 } reject
          }
        }
      '';
    };
    systemd.services.divi = {
      serviceConfig = {
        ExecStart = "${pkgs.tayga}/bin/tayga -d --config ${pkgs.writeText "divi.conf" ''
          tun-device divi
          ipv4-addr 10.208.0.2
          prefix ${pre}
          dynamic-pool 10.208.0.0/12
          data-dir /var/spool/tayga
        ''}";
      };
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };
    systemd.network.config = { networkConfig = { IPv6Forwarding = true; }; };
    systemd.network.networks = {
      divi = {
        name = "divi";
        linkConfig = { RequiredForOnline = false; };
        addresses = [
          { Address = "10.208.0.1/12"; PreferredLifetime = 0; }
          { Address = address; PreferredLifetime = 0; }
        ];
        networkConfig = {
          IPv4Forwarding = true;
          IPMasquerade = "ipv4";
        };
        routes = [
          { Destination = pre; }
        ];
        routingPolicyRules = [
          { To = pre; Priority = 150; }
          # make sure this takes precedence cf. ivi default rule with no fwmark
          { To = "10.208.0.0/12"; Priority = 50; }
        ];
      };
    };
  };
}
