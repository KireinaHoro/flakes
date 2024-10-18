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
      description = "server selection strings";
    };
    addresses = mkOption {
      type = types.listOf types.str;
      description = "address directives, can be used to block stuff";
      default = [];
    };
    listenAddrs = mkOption {
      type = types.listOf types.str;
      description = "addresses to listen on for DNS requests";
    };
    configDirs = mkOption {
      type = types.listOf types.str;
      description = "list of configuration file directories for resolver config";
    };
    logQueries = mkEnableOption "log all queries";
  };
  config = mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        server = cfg.servers ++ [ "/gravity/2a0c:b641:69c:7864:0:5:0:3" ];
        address = cfg.addresses;
        listen-address = cfg.listenAddrs;
        bind-dynamic = true;
        no-resolv = true;
        no-hosts = true;
        conf-dir = cfg.configDirs;
      } // optionalAttrs cfg.logQueries {
        log-queries = true;
        log-facility = "local0";
      };
    };
    systemd.services.dnsmasq = {
      serviceConfig = {
        TimeoutStartSec = "infinity";
      };
    };
  };
}
