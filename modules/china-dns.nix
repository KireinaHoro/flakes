{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.chinaDNS;
  chinaList = pkgs.dnsmasq-china-list.overrideAttrs (_: {
    server = cfg.chinaServer;
  });
in
{
  options.services.chinaDNS = {
    enable = mkEnableOption "local resolver to accelerate China DNS traffic";
    servers = mkOption {
      type = types.listOf types.str;
      default = [ "8.8.8.8" "8.8.4.4" ];
    };
    ifName = mkOption {
      type = types.str;
      description = "which interface to listen on for DNS queries";
    };
    chinaServer = mkOption {
      type = types.str;
      default = "114.114.114.114";
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
        conf-dir=${chinaList}/dnsmasq
      '';
    };
  };
}
