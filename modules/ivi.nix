{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.ivi;
  hostname = config.networking.hostName;
  my = pkgs.gravityHostByName hostname;
  prefix4 = my pkgs.gravityHostToIviPrefix4;
  prefix6 = my ({id, ...}:
    "${pkgs.gravityHomePrefix}:${id}5:0:5");
  defaultMap = optionalString (cfg.default != null) (let
    p = pkgs.gravityHostByName cfg.default pkgs.gravityHostToDiviPrefix;
  in "${p.prefix}/${toString p.len}");
in
{
  options.services.ivi = {
    enable = mkEnableOption "ivi nat46";
    fwmark = mkOption {
      type = types.nullOr types.int;
      description = "firewall mark for packets to ivi";
      default = null;
    };
    default = mkOption {
      type = types.nullOr types.str;
      description = "nat46 default destination hostname";
      example = "nick_sin";
      default = null;
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
        ExecStart = with pkgs; "${tayga}/bin/tayga -d --config ${writeText "ivi.conf" ''
          tun-device ivi
          ipv4-addr 10.160.0.2
          ipv6-addr ${prefix6}::2
          ${optionalString (cfg.default != null) "map 0.0.0.0/0 ${defaultMap}"}
          ${genIviMap prefix4.prefix prefix6 prefix4.len}

          ${concatStringsSep "\n"
          (gravityHostsExclude ([hostname] ++ optional (cfg.default != null) cfg.default)
            (h: let
              v4 = gravityHostToIviPrefix4 h;
              v6 = gravityHostToDiviPrefix h;
            in genIviMap v4.prefix v6.prefix v4.len))}

          ${cfg.extraConfig}
        ''}";
      };
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };
    systemd.network.networks = {
      ivi = {
        name = "ivi";
        linkConfig = { RequiredForOnline = false; };
        addresses = [
          { Address = "${removeSuffix "0" prefix4.prefix}1/12"; PreferredLifetime = 0; }
          { Address = "${prefix6}::/96"; PreferredLifetime = 0; }
        ];
        routes = [
          { Destination = "0.0.0.0/0"; Table = 3500; }
        ];
        routingPolicyRules = [
          # first check if is local peer
          {
            To = "${prefix4.prefix}/${toString prefix4.len}";
            Priority = 50;
          }
          # then if still gravity, send to ivi for outgoing
          ({ From = "10.160.0.0/12"; Table = 3500; Priority = 100; } //
            optionalAttrs (cfg.fwmark != null) { FirewallMark = cfg.fwmark; })
          {
            Family = "ipv6";
            IncomingInterface = "ivi";
            Table = 3500;
            Priority = 100;
          }
          { To = "${prefix6}::/96"; Priority = 150; }
        ];
      };
    };
  };
}
