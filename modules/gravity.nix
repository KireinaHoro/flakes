{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.gravity;
  raitConfigFile = config.sops.templates."rait.conf".path;
  ip = "${pkgs.iproute2}/bin/ip";

  hostname = config.networking.hostName;
  my = pkgs.gravityHostByName hostname;
  localPrefix = my pkgs.gravityHostToPrefix;

  gravityPartDepend = after: {
    partOf = [ "gravity.service" ];
    after = [ "gravity.service" ] ++ after;
    requires = [ "gravity.service" ];
    requiredBy = [ "gravity.service" ];
  };
  gravityPart = gravityPartDepend [];
  routeDaemon = if cfg.bird.enable then "bird" else "babeld";
  backbonePartExtraDep = deps: let
    selectService = name: optional (routeDaemon == name) "gravity-${name}.service";
  in gravityPartDepend ((concatMap selectService ["bird" "babeld"]) ++ deps);
  backbonePart = backbonePartExtraDep [];

  jsonEmitter = (pkgs.formats.json {}).generate;
in
{
  options.services.gravity = {
    enable = mkEnableOption "gravity overlay network";
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
    homePrefix = mkOption {
      type = types.str;
      description = "gravity home prefix (always routed into gravity)";
      default = "2a0c:b641:69c::/48";
    };
    fwmark = mkOption {
      type = types.int;
      description = "fwmark for IPv6 gravity wireguard packets";
      default = 56;
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
    babeld = {
      enable = mkEnableOption "babeld for routing";
      socket = mkOption {
        type = types.str;
        description = "path of babeld control socket";
        default = "/run/babeld.ctl";
      };
    };
    bird = {
      enable = mkEnableOption "bird for routing";
      socket = mkOption {
        type = types.str;
        description = "path of bird control socket";
        default = "/run/bird.ctl";
      };
      filterExpr = mkOption {
        type = types.str;
        description = "filter expression to export to kernel routing table";
        default = "all";
        example = "filter { if net ~ [${cfg.homePrefix}+] then accept; reject; }";
      };
    };

    # backbone selection
    rait = {
      enable = mkEnableOption "rait for WireGuard backbone";
      secretNames = {
        operatorKey = mkOption { type = types.str; default = "rait-operator-key"; };
        nodeKey = mkOption { type = types.str; default = "rait-node-key"; };
        registry = mkOption { type = types.str; default = "rait-registry"; };
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
    };
    ranet = {
      enable = mkEnableOption "ranet for IPsec backbone";
      secretNames = {
        key = mkOption { type = types.str; default = "ranet-key"; };
        registry = mkOption { type = types.str; default = "ranet-registry"; };
      };
      organization = mkOption { type = types.str; default = "jsteward"; };
      viciSocket = mkOption {
        type = types.str;
        description = "path of vici control socket";
        default = "/run/gravity-charon.vici";
      };
      port = mkOption {
        type = types.int;
        description = "IPsec port for send/receive";
        default = 13000;
      };
      localIf = mkOption {
        type = types.str;
        description = "local interface for IPsec traffic";
      };
      gravityIfPrefix = mkOption {
        type = types.str;
        description = "prefix for gravity interface names inside netns";
        default = "swan";
      };
      endpoints = mkOption {
        type = types.listOf (types.submodule { options = {
          address = mkOption { type = types.nullOr types.str; default = null; };
          address_family = mkOption { type = types.enum [ "ip4" "ip6" ]; };
        }; });
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion =
        (cfg.bird.enable && !cfg.babeld.enable) ||
        (cfg.babeld.enable && !cfg.bird.enable);
        message = "exactly one of bird and babeld should be enabled"; }
      { assertion = cfg.rait.enable || cfg.ranet.enable;
        message = "at least one of ranet (IPsec) and rait (WireGuard) should be enabled"; }

      # rait checks
      { assertion = cfg.rait.enable -> length cfg.rait.transports >= 1;
        message = "must define at least one transport"; }

      # ranet checks
      { assertion = cfg.ranet.enable -> cfg.bird.enable;
        message = "ranet does not support babeld, must enable bird"; }
      { assertion = cfg.rait.enable ->
          cfg.ranet.gravityIfPrefix != "grv4x" && cfg.ranet.gravityIfPrefix != "grv6x";
        message = "dangerous prefix that may collide with rait"; }
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

        ${optionalString cfg.babeld.enable ''
          babeld {
            enabled = true
            socket_type = "unix"
            socket_addr = "${cfg.babeld.socket}"
            footnote = "interface host type wired"
          }
        ''}

        remarks = {
          name = "${config.networking.hostName}"
          prefix = "${localPrefix}"
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
          address = [ (pkgs.hostInV6Prefix localPrefix "1") ];
          routes = [ { Destination = "::/0"; Gateway = "fe80::200:ff:fe00:2"; Table = cfg.gravityTable; } ];
          routingPolicyRules = [
            { Family = "ipv6"; FirewallMark = cfg.fwmark; Priority = 50; }
            # this blackhole rule is preferred (in case default route in main disappeared)
            { Family = "ipv6"; FirewallMark = cfg.fwmark; Type = "blackhole"; Priority = 51; }
            { To = cfg.homePrefix; Table = cfg.gravityTable; Priority = 200; }
            { From = cfg.homePrefix; Table = cfg.gravityTable; Priority = 200; }
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
    } // backbonePart);
    systemd.services.gravity-rait-sync = mkIf cfg.rait.enable ({
      serviceConfig = with pkgs; {
        Type = "oneshot";
        User = "root";
        ExecStart = "${rait}/bin/rait sync -c ${raitConfigFile}";
      };
    } // backbonePart);

    systemd.timers.gravity-ranet-sync = mkIf cfg.ranet.enable ({
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "gravity-ranet-sync.service";
      };
    } // backbonePart);
    systemd.services.gravity-ranet-sync = mkIf cfg.ranet.enable ({
      serviceConfig = with pkgs; let
        registryUrlFile = config.sops.secrets.${cfg.ranet.secretNames.registry}.path;
        keyFile = config.sops.secrets.${cfg.ranet.secretNames.key}.path;
        registryFile = "/run/secrets/ranet-registry.reg";
        configFile = jsonEmitter "ranet.conf" {
          organization = cfg.ranet.organization;
          common_name = hostname;
          endpoints = imap0 (idx: ep: ep // {
            serial_number = toString idx;
            port = cfg.ranet.port;
            updown = "${swan-updown}/bin/swan-updown " +
              "-p ${cfg.ranet.gravityIfPrefix} " +
              "-n ${cfg.netns} -d";
          }) cfg.ranet.endpoints;
        };
        doRanet = a: "${ranet}/bin/ranet -k ${keyFile} -v ${cfg.ranet.viciSocket} -r ${registryFile} -c ${configFile} ${a}";
        doUpdateReg = writeShellScript "update-ranet-registry" ''
          ${curl}/bin/curl -s $(<${registryUrlFile}) > ${registryFile}
        '';
      in {
        Type = "oneshot";
        User = "root";
        ExecStart = [
          doUpdateReg
          (doRanet "up")
        ];
      };
    } // backbonePartExtraDep ["gravity-strongswan.service"]);
    systemd.services.gravity-strongswan = mkIf cfg.ranet.enable (with pkgs; let
      viciUri = "unix://${cfg.ranet.viciSocket}";
      swanctl = a: "${strongswan}/sbin/swanctl ${a} --uri ${viciUri}";
    in {
      # mirror of the upstream strongswan.service
      serviceConfig = {
        Type = "notify";
        ExecStart = "${strongswan}/sbin/charon-systemd";
        ExecStartPost = swanctl "--load-all --noprompt";
        ExecReload = [
          (swanctl "--reload")
          (swanctl "--load-all --noprompt")
        ];
        Restart = "on-abnormal";
      };
      environment = {
        STRONGSWAN_CONF = pkgs.writeText "strongswan.conf" ''
          charon {
            interfaces_use = ${cfg.ranet.localIf}
            port = 0
            port_nat_t = ${toString cfg.ranet.port}
            retransmit_base = 1
            plugins {
              socket-default {
                set_source = yes
                set_sourceif = yes
              }
              dhcp {
                load = no
              }
              vici {
                socket = ${viciUri}
              }
            }
            syslog {
              daemon {
                default = -1
                log_level = 0
              }
            }
          }
          charon-systemd {
            journal {
              default = -1
              ike = 0
            }
          }
        '';
      };
    } // backbonePart);

    systemd.services.gravity-babeld = mkIf cfg.babeld.enable ({
      serviceConfig = with pkgs; {
        NetworkNamespacePath = "/run/netns/${cfg.netns}";
        ExecStart = "${babeld}/bin/babeld -c ${writeText "babeld.conf" ''
          random-id true
          local-path-readwrite ${cfg.babeld.socket}
          state-file ""
          pid-file ""
          interface placeholder

          redistribute local deny
          redistribute ip ${cfg.homePrefix} ge 56 le 64 allow
        ''}";
        Restart = "always";
        RestartSec = 5;
      };
    } // gravityPart);

    systemd.services.gravity-bird = mkIf cfg.bird.enable ({
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
              optional cfg.ranet.enable "${cfg.ranet.gravityIfPrefix}*" ++
              optionals cfg.rait.enable [ "grv4x*" "grv6x*" ]));
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
          "${ip} -n ${cfg.netns} addr add ${pkgs.hostInV6Prefix localPrefix "2"} dev host"
          "${ip} -n ${cfg.netns} route add ${localPrefix} via fe80::200:ff:fe00:1 dev host metric 1 proto static"
          "${ip} -n ${cfg.netns} addr add ${localPrefix} dev lo"
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
