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
    };
  };
}
