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
    ifName = mkOption {
      type = types.str;
      description = "which interface to listen on for DNS queries";
    };
    configDirs = mkOption {
      type = types.listOf types.str;
      description = "list of configuration file directories for resolver config";
    };
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
        interface=${cfg.ifName}
        bind-interfaces
        no-resolv
        log-queries
        log-facility=local0
        ${concatStrings (map (c: "conf-dir=${c}\n") cfg.configDirs)}
        ${cfg.extraConfig}
      '';
    };
    systemd.services.dnsmasq = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}
