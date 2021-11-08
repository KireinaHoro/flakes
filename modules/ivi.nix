{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.ivi;
  prefix4Length = cfg.prefixLength - 36;
in
{
  options.services.ivi = {
    enable = mkEnableOption "ivi nat46";
    prefix4 = mkOption {
      type = types.str;
      description = "nat46 ipv4 prefix";
      example = "10.172.208.0";
    };
    fwmark = mkOption {
      type = types.nullOr types.int;
      description = "firewall mark for packets to ivi";
      default = null;
    };
    prefix6 = mkOption {
      type = types.str;
      description = "nat46 ipv6 prefix";
      example = "2a0c:b641:69c:cd05:0:5";
    };
    defaultMap = mkOption {
      type = types.str;
      description = "nat46 default destination";
      example = "2a0c:b641:69c:f254:0:4::/96";
    };
    prefixLength = mkOption {
      type = types.int;
      description = "IPv6 subnet prefix length";
    };
    extraConfig = mkOption {
      type = types.str;
      description = "extra config to insert";
      default = "";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.ivi = {
      serviceConfig = {
        ExecStart = "${pkgs.tayga}/bin/tayga -d --config ${pkgs.writeText "ivi.conf" ''
          tun-device ivi
          ipv4-addr 10.160.0.2
          ipv6-addr ${cfg.prefix6}::2
          map 0.0.0.0/0 ${cfg.defaultMap}
          ${pkgs.genIviMap cfg.prefix4 cfg.prefix6 prefix4Length}

          ${cfg.extraConfig}
        ''}";
      };
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };
    systemd.network.networks = {
      ivi = {
        name = "ivi";
        addresses = [
          { addressConfig = { Address = "${removeSuffix "0" cfg.prefix4}1/12"; PreferredLifetime = 0; }; }
          { addressConfig = { Address = "${cfg.prefix6}::/96"; PreferredLifetime = 0; }; }
        ];
        routes = [
          { routeConfig = { Destination = "0.0.0.0/0"; Table = 3500; }; }
        ];
        routingPolicyRules = [
          { routingPolicyRuleConfig = { From = "10.160.0.0/12"; Table = 3500; Priority = 100; } //
            (if cfg.fwmark == null then {} else { FirewallMark = cfg.fwmark; });
          }
          { routingPolicyRuleConfig = {
            To = "${cfg.prefix4}/${toString prefix4Length}";
            Priority = 100;
          }; }
          { routingPolicyRuleConfig = {
            Family = "ipv6";
            IncomingInterface = "ivi";
            Table = 3500;
            Priority = 100;
          }; }
          { routingPolicyRuleConfig = { To = "${cfg.prefix6}::/96"; Priority = 150; }; }
        ];
      };
    };
  };
}
