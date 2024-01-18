{ config, pkgs, ... }:

let
  username = "jsteward";
  homeDir = "/Users/${username}";
in

{
  users.users.${username}.home = homeDir;

  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.users."${username}" = {
    home = {
      stateVersion = "24.05";
      sessionPath = [
        "${homeDir}/.local/bin/" # XXX: express with XDG?
        "${homeDir}/sdk/go1.20.3/bin"
        "${homeDir}/go/bin"
      ];
      packages = with pkgs; [ ripgrep coreutils ];
      file.".gnupg/gpg-agent.conf".text = ''
        max-cache-ttl 18000
        default-cache-ttl 18000
        enable-ssh-support
      '';
    };

    programs = {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      gpg = {
        enable = true;
        settings = {
          auto-key-retrieve = true;
          no-emit-version = true;
          default-key = "EEE87C527B2D913A8CBAD48C725079137D8A5B65";
          encrypt-to = "i@jsteward.moe";
        };
      };

      zsh = {
        enable = true;
        syntaxHighlighting.enable = true;
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "gpg-agent" ];
          theme = "candy";
        };

        shellAliases = {
          ls = "ls -G --color=auto";
        };

        initExtra = ''
          # TMUX auto attach
          if which tmux >/dev/null 2>&1; then
            case $- in
              *i*) test -z "$TMUX" && (tmux attach || tmux new-session)
            esac
          fi

          # iTerm2 integration
          test -e "$HOME/.iterm2_shell_integration.zsh" && source "$HOME/.iterm2_shell_integration.zsh"

          # load homebrew
          # FIXME: we should eventually completely switch to nix-darwin
          if [ "$(arch)" = "arm64" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          else
            eval "$(/usr/local/bin/brew shellenv)"
          fi
        '';
      };

      autojump.enable = true;
      dircolors = {
        enable = true;
        enableZshIntegration = true;
      };
      bat.enable = true;
    };

  };
}
