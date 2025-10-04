{ config, pkgs, ... }:

with pkgs.lib;

let
  ifName = "eth0";
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "toride";
    useDHCP = false;
    firewall.enable = false;
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        address = [ "192.168.0.2/24" ];
        routes = [
          { Gateway = "192.168.0.1"; }
        ];
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.settings.PasswordAuthentication = false;
  };
}
