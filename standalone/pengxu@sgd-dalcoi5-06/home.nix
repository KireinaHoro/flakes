{ pkgs, lib, ... }:

let
  username = "pengxu";
  homeDirectory = "/local/home/${username}";
  workDir = "${homeDirectory}/work-local";
  xdgConfigHome = "${homeDirectory}/.config_ubuntu_22.04";
  # Kerberos (D.ETHZ.CH) for enzian-gateway and the build hosts: k5start keeps a
  # ticket in one shared cache from the keytab (created by hand with ktutil, mode
  # 600; recreate it after a password change), so shells, agents and detached
  # board-run units all authenticate unattended.
  keytab = "${homeDirectory}/.config/krb5/pengxu.keytab";
  krb5Cache = "FILE:\${XDG_RUNTIME_DIR}/krb5cc";
in

{
  imports = [ ../../hm-modules/home-common.nix ];

  nixpkgs.config.allowUnfree = true;
  programs = {
    vscode.enable = true;
    neovim = {
      enable = true;
      withPython3 = false;
      withRuby = false;
    };
  };

  systemd.user = {
    # environment.d: inherited by every user unit (systemd-run, detached runs).
    sessionVariables.KRB5CCNAME = krb5Cache;
    services.k5start = {
      Unit.Description = "Keep a Kerberos ticket for pengxu@D.ETHZ.CH from the keytab";
      Service = {
        # -U: principal from the keytab; -K 10: check every 10 min and renew or
        # re-kinit before expiry (tickets last 1 h here).
        ExecStart = "${pkgs.kstart}/bin/k5start -U -f ${keytab} -K 10 -k FILE:%t/krb5cc";
        Restart = "always";
        RestartSec = 30;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };

  home = {
    inherit username homeDirectory;

    # Sourced from ~/.zshenv (hm-session-vars.sh).
    sessionVariables.KRB5CCNAME = krb5Cache;

    file."${xdgConfigHome}/nix/nix.conf".text = ''
      experimental-features = nix-command flakes ca-derivations
    '';

    # create symlink for home-manager command
    activation.symlinkFlakes = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ln -snf $VERBOSE_ARG ${workDir}/flakes ${xdgConfigHome}/home-manager
    '';

    sessionPath = [
      # shell scripts from idea
      "$HOME/.local/share/JetBrains/Toolbox/scripts"
      # claude code
      "$HOME/.local/bin"
    ];

    packages = with pkgs; [
      codex
      texlive.combined.scheme-full librsvg
      texlivePackages.fontawesome
      ffmpeg-headless
      typst pdf2svg
      clang-tools
      gh git-lfs
      nix-search-cli
      shellcheck
    ];
  };
}
