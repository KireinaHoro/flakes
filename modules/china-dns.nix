{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.chinaDNS;
  chinaList = with cfg; pkgs.dnsmasq-china-list.override {
    server = chinaServer;
    inherit accelAppleGoogle;
  };
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
    accelAppleGoogle = mkOption {
      type = types.bool;
      default = true;
    };
  };
  config = mkIf cfg.enable {
    services.localResolver = {
      inherit (cfg) servers ifName enable;
      configDirs = [ "${chinaList}/dnsmasq" ];
    };
  };
}
