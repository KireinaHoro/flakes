{ config, pkgs, ... }:

let
  username = "jsteward";
  homeDir = "/Users/${username}";
in

{
  users.users.${username}.home = homeDir;

  home-manager.users."${username}" = {
    home = {
      sessionPath = [
        "${homeDir}/.local/bin/" # XXX: express with XDG?
        "${homeDir}/sdk/go1.20.3/bin"
        "${homeDir}/go/bin"
      ];
      packages = with pkgs; [ coreutils ];
      file.".gnupg/gpg-agent.conf".text = ''
        max-cache-ttl 18000
        default-cache-ttl 18000
        enable-ssh-support
      '';
    };
  };
}
