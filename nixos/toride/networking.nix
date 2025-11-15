{ config, pkgs, ... }:

with pkgs.lib;

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "toride";
    useDHCP = false;
    firewall.enable = false;

    hosts = {
      # we use local network address to deploy iori
      "10.172.190.254" = [ "iori.jsteward.moe" ];
      "192.168.178.67" = [ "iori.jsteward.moe" ];
    };
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      "eth0" = {
        address = [ "192.168.0.2/24" ];
        # only use default route here when the VLAN is broken
        # routes = [ { Gateway = "192.168.0.1"; } ];
        linkConfig.RequiredForOnline = "routable";
      };
      "eth1" = {
        # Switch to bridge into VLAN 200 (iori gravity)
        DHCP = "yes";
        linkConfig.RequiredForOnline = false;
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.settings = {
      PasswordAuthentication = false;
      X11Forwarding = true;
    };
  };
}
