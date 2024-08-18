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
        "${homeDir}/sdk/go1.20.3/bin"
        "${homeDir}/go/bin"
        "${homeDir}/.ghcup/bin"
      ];
      packages = with pkgs; [ coreutils jdk verilator ];
    };

    programs.zsh.initExtra = ''
      # load homebrew
      # FIXME: we should eventually completely switch to nix-darwin
      if [ "$(arch)" = "arm64" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi

      # remove walters RPS1
      unset RPS1
    '';
  };
}
