{ config, pkgs, ... }:

with pkgs.lib;

let
  iviDiviPrefix = "2a0c:b641:69c:ce0";
  gravityAddr = last: "${iviDiviPrefix}0::${last}/${toString prefixLength}";
  raitSecret = config.sops.secrets.rait.path;
  ifName = "ens3";
  prefixLength = 60;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "kage";
    useDHCP = false;
    firewall.enable = false;
  };

  # FIXME merge masquerade into networkd configuration
  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${iviDiviPrefix}0::/${toString prefixLength} log prefix "Unknown source to WAN: " drop
        }
        chain nat {
          type nat hook postrouting priority 100;
          oifname "${ifName}" masquerade;
        }
      }
    '';
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        DHCP = "ipv4";
        networkConfig = {
          IPv6PrivacyExtensions = true;
          # FIXME we cannot use this until systemd v248. ref:
          # IPv6 masquerade: https://github.com/systemd/systemd/commit/b1b4e9204c8260956825e2b9733c95903e215e31
          # nft backend: https://github.com/systemd/systemd/commit/a8af734e75431d676b25afb49ac317036e6825e6
          # IPMasquerade = "ipv4";
        };
      };
    };
  };

  services = {
    vnstat = { enable = true; };

    openssh.passwordAuthentication = false;

    gravity = rec {
      enable = true;
      config = raitSecret;
      netnsAddress = gravityAddr "2";
      address = gravityAddr "1";
      subnet = gravityAddr "";
      inherit prefixLength;
    };

    divi = {
      enable = true;
      prefix = "${iviDiviPrefix}4:0:4::/96";
      address = "${iviDiviPrefix}4:0:5:0:3/128";
      inherit ifName;
    };

    ivi = {
      enable = true;
      prefix4 = "10.172.224.0";
      prefix6 = "${iviDiviPrefix}5:0:5";
      defaultMap = "2a0c:b641:69c:f254:0:4::/96";
      inherit prefixLength;
    };

    squid = {
      enable = true;
      extraConfig = ''
        acl localnet src 2a0c:b641:69c::/48 10.160.0.0/12 127.0.0.1 ::1

        http_access allow CONNECT localnet
        icp_access allow localnet
        htcp_access allow localnet

        cache_dir aufs /var/cache/squid 500 16 256
        maximum_object_size 65536 KB

        logformat combined  %>a %ui %un [%tl] "%rm %ru HTTP/%rv" %>Hs %<st "%{Referer}>h" "%{User-Agent}>h" %Ss:%Sh
        logfile_rotate 0

        negative_ttl 0
        icp_port 3130
      '';
    };

    aria2 = {
      enable = true;
      extraArguments = with pkgs; let
          ariaHome = "/var/lib/aria2";
          downloads = "${ariaHome}/Downloads";
          log = "${ariaHome}/mvcompleted.log";
          rc = "${rclone}/bin/rclone --verbose --config=${ariaHome}/rclone.conf";
          mvcompleted = writeScript "mvcompleted" ''
            #!${bash}/bin/bash

            set -eu

            err() {
              echo $(${coreutils}/bin/date) ERR:  $@ >> ${log}
              exit 1
            }
            info() {
              echo $(${coreutils}/bin/date) INFO: $@ >> ${log}
            }

            if [[ "$2" == "0" ]]; then
              info "No file to move for $1"
              exit 0
            fi

            src="$3"
            while true; do
              dir=$(${coreutils}/bin/dirname "$src")
              if [[ "$dir" == "${downloads}" ]]; then
                tgt="gdrive:archive/Uncategorized/''${src##*/}"
                info "Uploading $1 $src..."
                ${rc} copyto "$src" "$tgt" &>> ${log} || err "Failed to run rclone"
                info "$1 $3 moved as $tgt"
                ${coreutils}/bin/rm -rf "$src" &>> ${log}
                exit 0
              elif [[ "$dir" == "/" || "$dir" == "." ]]; then
                err "$1 $3 not under ${downloads}"
              else
                src="$dir"
              fi
            done
          '';
        in replaceStrings [ "\n" ] [ " " ] ''
        --continue=true
        --input-file=${ariaHome}/aria2.session
        --max-connection-per-server=10
        --seed-time=0
        --max-concurrent-downloads=4
        --max-connection-per-server=16
        --on-download-complete=${mvcompleted}
        --on-bt-download-complete=${mvcompleted}
      '';
    };

    nginx = {
      enable = true;
      virtualHosts = {
        "jsteward.moe" = {
          forceSSL = true;
          enableACME = true;
          serverAliases = [ "aria2.jsteward.moe" ];
          locations."/" = { root = pkgs.jstewardMoe; };
        };
        "aria2.jsteward.moe" = {
          forceSSL = true;
          useACMEHost = "jsteward.moe";
          locations = {
            "/" = { root = "${pkgs.ariang}/dist/"; };
            "/jsonrpc" = {
              proxyPass = "http://localhost:6800";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header   Host $host;
                proxy_set_header   X-Real-IP $remote_addr;
                proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header   X-Forwarded-Host $server_name;
              '';
            };
          };
        };
      };
    };
  };

  systemd.services.aria2 = {
    preStart = ''
      ${pkgs.gnused}/bin/sed -i -e "s/rpc-secret.*$/rpc-secret=$RPC_SECRET/" /var/lib/aria2/aria2.conf
    '';
    serviceConfig.EnvironmentFile = [
      config.sops.secrets.aria2-env.path
    ];
  };
}
