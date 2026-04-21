{ pkgs, lib, ... }:

let
  username = "pengxu";
  homeDirectory = "/local/home/${username}";
  workDir = "${homeDirectory}/work-local";
  xdgConfigHome = "${homeDirectory}/.config_ubuntu_22.04";
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

  home = {
    inherit username homeDirectory;

    file."${xdgConfigHome}/nix/nix.conf".text = ''
      experimental-features = nix-command flakes ca-derivations
    '';

    # create symlink for home-manager command
    activation.symlinkFlakes = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ln -snf $VERBOSE_ARG ${workDir}/flakes ${xdgConfigHome}/home-manager
    '';

    # add shell script from idea
    sessionPath = [
      "${homeDirectory}/.local/share/JetBrains/Toolbox/scripts"
    ];

    packages = with pkgs; [
      texlive.combined.scheme-full librsvg
      texlivePackages.fontawesome
      ffmpeg-headless
      typst pdf2svg
      clang-tools
      gh
      nix-search-cli
      shellcheck
    ];
  };
}
