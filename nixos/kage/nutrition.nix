{ config, ... }:

let
  tunnelId = "tunnel_6a8ff61e7dc4819193358c364649f9c9";
in
{
  services.mcp-nutrition-db = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 8787;
    defaultTimezone = "Europe/Zurich";
    logLevel = "info";
    stateDirectory = "mcp-nutrition-db";

    backup = {
      enable = true;
      directory = "/var/backup/mcp-nutrition-db";
      onCalendar = "Sun *-*-* 04:00:00";
      randomizedDelaySec = "30m";
      retention = "26W";
    };
  };

  services.openai-tunnel-client.instances.nutrition = {
    enable = true;
    settings = {
      config_version = 1;
      control_plane = {
        tunnel_id = tunnelId;
        # The client resolves one secret reference layer only. Point it at the
        # systemd credential directly instead of nesting file: inside env:.
        api_key = "file:/run/credentials/tunnel-client-nutrition.service/control-plane-api-key";
      };
      health.listen_addr = "127.0.0.1:8788";
      admin_ui.open_browser = false;
      log = {
        level = "info";
        format = "json";
      };
      mcp.server_urls = [
        {
          channel = "main";
          url = "http://127.0.0.1:8787/mcp";
        }
      ];
    };
  };

  systemd.services.tunnel-client-nutrition = {
    requires = [ "mcp-nutrition-db.service" ];
    after = [ "mcp-nutrition-db.service" ];
    serviceConfig.LoadCredential = [
      "control-plane-api-key:${config.sops.secrets.mcp-nutrition-db-tunnel-apikey.path}"
    ];
  };
}
