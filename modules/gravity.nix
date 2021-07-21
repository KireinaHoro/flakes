{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.gravity;
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
    group = mkOption {
      type = types.int;
      description = "ifgroup of link connecting netns";
      default = 0;
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
    subnet = mkOption {
      type = types.str;
      description = "route to local subnet";
      example = "2a0c:b641:69c:cd00::/56";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.gravity = {
      serviceConfig = with pkgs;{
        ExecStartPre = [
          "${iproute2}/bin/ip netns add ${cfg.netns}"
          "${iproute2}/bin/ip link add ${cfg.link} address 00:00:00:00:00:01 group ${toString cfg.group} type veth peer host address 00:00:00:00:00:02 netns ${cfg.netns}"
          "${iproute2}/bin/ip link set ${cfg.link} up"
          "${iproute2}/bin/ip route add ${cfg.route} via fe80::200:ff:fe00:2 dev ${cfg.link}"
          "${iproute2}/bin/ip route add default via fe80::200:ff:fe00:2 dev ${cfg.link} table 3500"
          "${iproute2}/bin/ip addr add ${cfg.address} dev ${cfg.link}"

          "${iproute2}/bin/ip -n ${cfg.netns} link set host up"
          "${iproute2}/bin/ip -n ${cfg.netns} link set lo up"
          "${iproute2}/bin/ip -n ${cfg.netns} addr add ${cfg.netnsAddress} dev host"
          "${iproute2}/bin/ip -n ${cfg.netns} route add ${cfg.subnet} via fe80::200:ff:fe00:1 dev host metric 1 proto static"
          "${iproute2}/bin/ip -n ${cfg.netns} addr add ${cfg.subnet} dev lo"
        ];
        ExecStart = "${iproute2}/bin/ip netns exec ${cfg.netns} ${babeld}/bin/babeld -c ${writeText "babeld.conf" ''
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
        ExecStopPost = [
          "${iproute2}/bin/ip netns del ${cfg.netns}"
          "${iproute2}/bin/ip link del ${cfg.link}"
        ];
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
