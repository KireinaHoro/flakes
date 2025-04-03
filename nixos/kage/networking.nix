{ config, pkgs, ... }:

with pkgs.lib;

let
  my = pkgs.gravityHostByName config.networking.hostName;
  gravityPrefix = my pkgs.gravityHostToPrefix;

  ifName = "ens3";
  backupHost = "jsteward@toride.g.jsteward.moe";
  backupSecret = config.sops.secrets.toride-backup-key.path;
in

{
  # networking utils
  environment.systemPackages = with pkgs; [ mtr tcpdump socat ];

  networking = {
    hostName = "kage";
    useDHCP = false;
    firewall.enable = false;
  };

  networking.nftables = {
    ruleset = ''
      table inet local-wan {
        chain filter {
          type filter hook forward priority 100;
          oifname "${ifName}" ip saddr != { 10.160.0.0/12, 10.208.0.0/12 } log prefix "Unknown source to WAN: " drop
          oifname "${ifName}" ip6 saddr != ${gravityPrefix} log prefix "Unknown source to WAN: " drop
        }
      }
    '';
  };

  systemd.network = {
    networks = pkgs.injectNetworkNames {
      ${ifName} = {
        DHCP = "ipv4";
        networkConfig = { IPv6PrivacyExtensions = "prefer-public"; };
      };
    };
  };

  services = {
    fail2ban.enable = true;

    # workaround in https://github.com/NixOS/nixpkgs/pull/275031#issuecomment-1891052685
    dovecot2.sieve = {
      plugins = [ "sieve_imapsieve" "sieve_extprograms" ];
      extensions = [ "fileinto" ];
      globalExtensions = [ "+vnd.dovecot.pipe" "+vnd.dovecot.environment" ];
    };

    vnstat = { enable = true; };

    openssh.settings.PasswordAuthentication = false;

    gravity = rec {
      enable = true;

      rait = {
        enable = true;
        transports = [
          { family = "ip4"; sendPort = 55555; mtu = 1420;
            address = "kage.jsteward.moe"; }
          { family = "ip6"; sendPort = 56666; mtu = 1400;
            address = "kage.jsteward.moe"; }
        ];
      };
      ranet = {
        enable = true;
        localIf = ifName;
        endpoints = [
          { address_family = "ip4"; address = "kage.jsteward.moe"; }
          { address_family = "ip6"; address = "kage.jsteward.moe"; }
        ];
      };
      bird.enable = true;
    };

    divi = {
      enable = true;
      inherit ifName;
    };

    ivi = {
      enable = true;
      default = "nick_sin";
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

    roundcube = {
      enable = true;
      hostName = "webmail.jsteward.moe";
      extraConfig = ''
       # starttls needed for authentication, so the fqdn required to match
       # the certificate
       $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
       $config['smtp_user'] = "%u";
       $config['smtp_pass'] = "%p";
      '';
    };

    nginx = {
      enable = true;
      virtualHosts = {
        "jsteward.moe" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = { root = pkgs.jstewardMoe; };
        };
      };
    };
  };

  mailserver = {
    enable = true;
    fqdn = "mail.jsteward.moe";
    domains = [ "jsteward.moe" ];
    loginAccounts = {
      "i@jsteward.moe" = {
        hashedPasswordFile = config.sops.secrets.mailbox-passwd-hash.path;
        aliases = [ "postmaster@jsteward.moe" "abuse@jsteward.moe" ];
      };
    };
    certificateScheme = "acme-nginx";
    fullTextSearch = {
      enable = true;
      autoIndex = true;
      autoIndexExclude = [ "\\Junk" ];
      enforced = "body";
      memoryLimit = 500;
    };
    indexDir = "/var/lib/dovecot/indices";
  };

  # backup vmail and dkim
  systemd.timers."mail-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1d";
      OnUnitActiveSec = "1d";
      Unit = "mail-backup.service";
    };
  };
  systemd.services."mail-backup" = {
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = with pkgs; ''
        ${rsync}/bin/rsync -azhe"${openssh}/bin/ssh -o IdentityFile=${backupSecret} -o StrictHostKeyChecking=no" /var/vmail /var/dkim ${backupHost}:backups/
      '';
    };
  };
}
