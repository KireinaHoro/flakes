{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.gravity;
  ip = "${pkgs.iproute2}/bin/ip";
in
{
  options.services.gravity = {
    enable = mkEnableOption "gravity overlay network";
    config = mkOption {
      type = types.path;
      description = "path to rait config";
    };
    address = mkOption {
      type = types.str;
      description = "address to add into main netns";
    };
    netnsAddress = mkOption {
      type = types.str;
      description = "address to add into netns (as icmp source address)";
    };
    netns = mkOption {
      type = types.str;
      description = "name of netns for wireguard interfaces";
      default = "gravity";
    };
    link = mkOption {
      type = types.str;
      description = "name of link connecting netns";
      default = "gravity";
    };
    socket = mkOption {
      type = types.str;
      description = "path of babeld control socket";
      default = "/run/babeld.ctl";
    };
    postStart = mkOption {
      type = types.listOf types.str;
      description = "additional commands to run after startup";
      default = [ ];
    };
    prefixLength = mkOption {
      type = types.int;
      description = "prefix length of local subnet";
      default = 60;
    };
    route = mkOption {
      type = types.str;
      description = "route to gravity";
      default = "2a0c:b641:69c::/48";
    };
    fwmark = mkOption {
      type = types.int;
      description = "fwmark for IPv6 gravity wireguard packets";
      default = 56;
    };
    subnet = mkOption {
      type = types.str;
      description = "route to local subnet";
      example = "2a0c:b641:69c:cd00::/56";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ wireguard-tools ];

    systemd.network = {
      netdevs = pkgs.injectNetdevNames {
        # the peer will be moved into netns before starting
        ${cfg.link} = {
          netdevConfig = { Kind = "veth"; MACAddress = "00:00:00:00:00:01"; };
          peerConfig = { Name = "host"; MACAddress = "00:00:00:00:00:02"; };
        };
      };
      networks = pkgs.injectNetworkNames {
        ${cfg.link} = {
          address = [ cfg.address ];
          routes = [ { routeConfig = { Destination = "::/0"; Gateway = "fe80::200:ff:fe00:2"; Table = 3500; }; } ];
          routingPolicyRules = [
            { routingPolicyRuleConfig = { Family = "ipv6"; FirewallMark = cfg.fwmark; Priority = 50; }; }
            # this blackhole rule is preferred (in case default route in main disappeared), but
            # Type="blackhole" is in systemd 248 https://github.com/systemd/systemd/commit/d7d1d18fd25e3d6c7f3d1841e0502fadb8cecbf9
            # { routingPolicyRuleConfig = { Family = "ipv6"; FirewallMark = cfg.fwmark; Type = "blackhole"; Priority = 51; }; }
          ];
        };
      };
    };

    systemd.services.gravity = {
      serviceConfig = with pkgs;{
        ExecStartPre = [
          # FIXME move to networkd when netns support lands there
          "${ip} netns add ${cfg.netns}"
          "${ip} link set host netns ${cfg.netns}"

          "${ip} -n ${cfg.netns} link set host up"
          "${ip} -n ${cfg.netns} link set lo up"
          "${ip} -n ${cfg.netns} addr add ${cfg.netnsAddress} dev host"
          "${ip} -n ${cfg.netns} route add ${cfg.subnet} via fe80::200:ff:fe00:1 dev host metric 1 proto static"
          "${ip} -n ${cfg.netns} addr add ${cfg.subnet} dev lo"
        ];
        ExecStart = "${ip} netns exec ${cfg.netns} ${babeld}/bin/babeld -c ${writeText "babeld.conf" ''
          random-id true
          local-path-readwrite ${cfg.socket}
          state-file ""
          pid-file ""
          interface placeholder

          redistribute local deny
          redistribute ip ${cfg.route} eq ${toString cfg.prefixLength} allow
        ''}";
        ExecStartPost = [
          "${rait}/bin/rait up -c ${cfg.config}"
        ] ++ cfg.postStart;
        ExecReload = "${rait}/bin/rait sync -c ${cfg.config}";
        ExecStopPost = [ "${ip} netns del ${cfg.netns}" ];
        Restart = "always";
        RestartSec = 5;
      };
      startLimitIntervalSec = 0;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
