{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.inadyn;
in
{
  options = {
    services.inadyn = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Internet Dynamic DNS Client
        '';
      };
      cfgFile = mkOption {
        default = "";
        type = types.path;
        description = ''
          Configuration file path for inadyn
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.inadyn = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.inadyn
        pkgs.iproute2
      ];
      description = "Internet Dynamic DNS Client";
      documentation = [ "man:inadyn" "man:inadyn.conf" "https://github.com/troglobit/inadyn" ];
      serviceConfig = {
        Type = "forking";
        ExecStart = ''${pkgs.inadyn}/bin/inadyn --config ${cfg.cfgFile} --cache-dir /var/cache/inadyn --pidfile /var/run/inadyn.pid'';
        Restart = "always";
        RestartSec = "10min";
      };
    };

    environment.systemPackages = [ pkgs.inadyn ];
  };
}
