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
      ];
      packages = with pkgs; [ coreutils ];
    };

    programs.zsh.initExtra = ''
      # load homebrew
      # FIXME: we should eventually completely switch to nix-darwin
      if [ "$(arch)" = "arm64" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi

      # iTerm2 integration
      test -e "$HOME/.iterm2_shell_integration.zsh" && source "$HOME/.iterm2_shell_integration.zsh"
    '';
  };
}
