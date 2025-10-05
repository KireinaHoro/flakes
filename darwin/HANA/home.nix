{ pkgs, ... }:

{
  imports = [ ../../modules/home-common.nix ];

  home = {
    sessionPath = [
      "${homeDir}/sdk/go1.20.3/bin"
      "${homeDir}/go/bin"
    ];
    packages = with pkgs; [
      coreutils clang
      texlive.combined.scheme-full
    ];
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

  programs.neovim.enable = true;
}
