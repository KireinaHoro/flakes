{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.localResolver;
in
{
  options.services.localResolver = {
    enable = mkEnableOption "local resolver with DNS split";
    servers = mkOption {
      type = types.listOf types.str;
    };
    listenAddr = mkOption {
      type = types.str;
      description = "address to listen on for DNS requests";
    };
    configDirs = mkOption {
      type = types.listOf types.str;
      description = "list of configuration file directories for resolver config";
    };
    logQueries = mkEnableOption "log all queries";
    extraConfig = mkOption {
      type = types.str;
      description = "additional config for dnsmasq";
      default = "";
    };
  };
  config = mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      inherit (cfg) servers;
      resolveLocalQueries = false;
      extraConfig = ''
        listen-address=${cfg.listenAddr}
        bind-dynamic
        no-resolv
        no-hosts
        ${if cfg.logQueries then ''
          log-queries
          log-facility=local0
        '' else ""}
        ${concatStrings (map (c: "conf-dir=${c}\n") cfg.configDirs)}
        ${cfg.extraConfig}

        server=/gravity/2a0c:b641:69c:7864:0:5:0:3
      '';
    };
    systemd.services.dnsmasq = {
      serviceConfig = {
        TimeoutStartSec = "infinity";
      };
    };
  };
}
