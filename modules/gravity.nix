{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.gravity;
  raitConfigFile = config.sops.templates."rait.conf".path;
  ip = "${pkgs.iproute2}/bin/ip";
  gravityPartDepend = after: {
    partOf = [ "gravity.service" ];
    after = [ "gravity.service" ] ++ after;
    requires = [ "gravity.service" ];
    requiredBy = [ "gravity.service" ];
  };
  gravityPart = gravityPartDepend [];
  raitPart = let
    selectService = name: optional (cfg.rait.routeDaemon == name) "gravity-${name}.service";
  in gravityPartDepend (concatMap selectService ["bird" "babeld"]);

  babeldEnable = cfg.rait.enable && cfg.rait.routeDaemon == "babeld";
  birdEnable = cfg.ranet.enable || (cfg.rait.enable && cfg.rait.routeDaemon == "bird");
in
{
  options.services.gravity = {
    enable = mkEnableOption "gravity overlay network";
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
    defaultRoute = mkOption {
      type = types.bool;
      description = "enable default IPv6 route to gravity";
      default = false;
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
    gravityTable = mkOption {
      type = types.int;
      description = "routing table number for gravity routes in main netns";
      default = 3500;
    };
    extraRoutePolicies = mkOption {
      type = types.listOf types.attrs;
      description = "extra systemd-network routing options to put on link";
      default = [];
    };

    # routing daemon selection
    babeld = mkOption {
      type = types.submodule { options = {
        socket = mkOption {
          type = types.str;
          description = "path of babeld control socket";
          default = "/run/babeld.ctl";
        };
      }; };
      default = {};
    };
    bird = mkOption {
      type = types.submodule { options = {
        socket = mkOption {
          type = types.str;
          description = "path of bird control socket";
          default = "/run/bird.ctl";
        };
        filterExpr = mkOption {
          type = types.str;
          description = "filter expression to export to kernel routing table";
          default = "all";
          example = "filter { if net ~ [${cfg.route}+] then accept; reject; }";
        };
      }; };
      default = {};
    };

    # backbone selection
    rait = mkOption {
      type = types.submodule { options = {
        enable = mkEnableOption "rait for WireGuard backbone";
        routeDaemon = mkOption {
          type = types.enum [ "bird" "babeld" ];
          default = "babeld";
        };
        secretNames = mkOption {
          type = types.submodule { options = {
            operatorKey = mkOption { type = types.str; default = "rait-operator-key"; };
            nodeKey = mkOption { type = types.str; default = "rait-node-key"; };
            registry = mkOption { type = types.str; default = "rait-registry"; };
          }; };
          default = {};
        };
        transports = mkOption {
          type = types.listOf (types.submodule { options = {
            family = mkOption { type = types.enum [ "ip4" "ip6" ]; };
            address = mkOption { type = types.nullOr types.str; default = null; };
            sendPort = mkOption { type = types.int; };
            mtu = mkOption { type = types.int; };
            randomPort = mkOption { type = types.bool; default = false; };
          }; });
        };
      }; };
      default = {};
    };
    ranet = mkOption {
      type = types.submodule { options = {
        enable = mkEnableOption "ranet for IPsec backbone";
      }; };
      default = {};
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion = cfg.rait.enable || cfg.ranet.enable;
        message = "at least one of ranet (IPsec) and rait (WireGuard) should be enabled"; }
      { assertion = cfg.rait.enable -> length cfg.rait.transports >= 1;
        message = "must define at least one transport"; }

      # TODO: implement these
      { assertion = !cfg.ranet.enable;
        message = "ranet (IPsec) not implemented yet"; }
    ];

    sops.templates."rait.conf".content = mkIf cfg.rait.enable ''
      registry = "${config.sops.placeholder.${cfg.rait.secretNames.registry}}"
      private_key = "${config.sops.placeholder.${cfg.rait.secretNames.nodeKey}}"
      operator_key = "${config.sops.placeholder.${cfg.rait.secretNames.operatorKey}}"
      namespace = "${cfg.netns}"


      ${concatStringsSep "\n" (map (t: let
        familyDigit = substring 2 1 t.family;
        mark = "5${familyDigit}";
      in ''
        transport {
          address_family = "${t.family}"
          ${optionalString (t.address != null) "address = \"${t.address}\""}
          send_port = ${toString t.sendPort}
          mtu = ${toString t.mtu}
          ifprefix = "grv${familyDigit}x"
          ifgroup = ${mark}
          fwmark = ${mark}
          random_port = ${boolToString t.randomPort}
        }
        '') cfg.rait.transports)}

        ${optionalString (cfg.rait.routeDaemon == "babeld") ''
          babeld {
            enabled = true
            socket_type = "unix"
            socket_addr = "${cfg.babeld.socket}"
            footnote = "interface host type wired"
          }
        ''}

        remarks = {
          name = "${config.networking.hostName}"
          prefix = "${cfg.subnet}"
        }
    '';

    environment.systemPackages = mkIf cfg.rait.enable (with pkgs; [ wireguard-tools ]);

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
          linkConfig = { RequiredForOnline = false; };
          address = [ cfg.address ];
          routes = [ { Destination = "::/0"; Gateway = "fe80::200:ff:fe00:2"; Table = cfg.gravityTable; } ];
          routingPolicyRules = [
            { Family = "ipv6"; FirewallMark = cfg.fwmark; Priority = 50; }
            # this blackhole rule is preferred (in case default route in main disappeared)
            { Family = "ipv6"; FirewallMark = cfg.fwmark; Type = "blackhole"; Priority = 51; }
            { To = cfg.route; Table = cfg.gravityTable; Priority = 200; }
            { From = cfg.route; Table = cfg.gravityTable; Priority = 200; }
          ] ++ cfg.extraRoutePolicies
            ++ optional cfg.defaultRoute { To = "::/0"; Table = cfg.gravityTable; Priority = 300; };
        };
      };
    };

    systemd.timers.gravity-rait-sync = mkIf cfg.rait.enable ({
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "gravity-rait-sync.service";
      };
    } // raitPart);
    systemd.services.gravity-rait-sync = mkIf cfg.rait.enable ({
      serviceConfig = with pkgs; {
        Type = "oneshot";
        User = "root";
        ExecStart = "${rait}/bin/rait sync -c ${raitConfigFile}";
      };
    } // raitPart);

    systemd.services.gravity-babeld = mkIf babeldEnable ({
      serviceConfig = with pkgs; {
        NetworkNamespacePath = "/run/netns/${cfg.netns}";
        ExecStart = "${babeld}/bin/babeld -c ${writeText "babeld.conf" ''
          random-id true
          local-path-readwrite ${cfg.babeld.socket}
          state-file ""
          pid-file ""
          interface placeholder

          redistribute local deny
          redistribute ip ${cfg.route} ge 56 le 64 allow
        ''}";
        Restart = "always";
        RestartSec = 5;
      };
    } // gravityPart);

    systemd.services.gravity-bird = mkIf birdEnable ({
      serviceConfig = with pkgs; {
        NetworkNamespacePath = "/run/netns/${cfg.netns}";
        Type = "forking";
        ExecStartPre = [
          # babeld enables forwarding automatically inside the namespace; bird does not
          "${ip} netns exec ${cfg.netns} ${procps}/bin/sysctl -w net.ipv6.conf.all.forwarding=1"
        ];
        ExecStart = "${bird}/bin/bird -s ${cfg.bird.socket} -c ${writeText "bird2.conf" (let
          interfacePatterns = concatStringsSep ", "
            (map (pattern: "\"${pattern}\"") (
              optional cfg.ranet.enable "swan*" ++
              optionals (cfg.rait.enable && cfg.rait.routeDaemon == "bird") [ "grv4x*" "grv6x*" ]));
        in ''
          ipv6 sadr table sadr6;
          router id 10.10.10.10;
          protocol device {
            scan time 5;
          }
          protocol kernel {
            metric 2048;
            ipv6 sadr {
              export ${cfg.bird.filterExpr};
              import none;
            };
          }
          protocol direct {
            interface "lo";
            ipv6 sadr;
          }
          protocol babel {
            ipv6 sadr {
              export all;
              import all;
            };
            randomize router id;
            interface ${interfacePatterns} {
              type tunnel;
              link quality etx;
              rxcost 32;
              hello interval 20 s;
              rtt cost 1024;
              rtt max 1024 ms;
              rx buffer 1500;
            };
          }
        '')}";
        ExecStop = "${bird}/bin/birdc -s ${cfg.bird.socket} down";
        ExecReload = "${bird}/bin/birdc -s ${cfg.bird.socket} configure";
        Restart = "on-failure";
        RestartSec = 5;
      };
    } // gravityPart);

    systemd.services.gravity = {
      serviceConfig = with pkgs; {
        # set up netns and veth pair and invoke rait (if enabled)
        # the routing daemons are separate services
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          # FIXME move to networkd when netns support lands there
          #       https://github.com/systemd/systemd/issues/11103
          "networkctl reload"
          "-${ip} netns add ${cfg.netns}" # do not panic when a stale netns was not deleted
          "${ip} link set host netns ${cfg.netns}"

          "${ip} -n ${cfg.netns} link set host up"
          "${ip} -n ${cfg.netns} link set lo up"
          "${ip} -n ${cfg.netns} addr add ${cfg.netnsAddress} dev host"
          "${ip} -n ${cfg.netns} route add ${cfg.subnet} via fe80::200:ff:fe00:1 dev host metric 1 proto static"
          "${ip} -n ${cfg.netns} addr add ${cfg.subnet} dev lo"
        ];
        ExecStop = [
          # restore host back to default namespace, or it will be deleted along with the netns
          "${ip} -n ${cfg.netns} link set host netns 1"
          "${ip} netns del ${cfg.netns}"
        ];
      };
      startLimitIntervalSec = 0;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
