{ config, lib, pkgs, ... }:

let
  username = "pengxu";
  homeDirectory = "/local/home/${username}";
  workDir = "${homeDirectory}/work-local";
  xdgConfigHome = "${homeDirectory}/.config_ubuntu_22.04";
in

{
  nixpkgs.config.allowUnfree = true;
  programs = {
    vscode.enable = true;
    neovim.enable = true;
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

    packages = with pkgs; [
      texlive.combined.scheme-full
      texlivePackages.fontawesome
      ffmpeg-headless
      typst pdf2svg
    ];
  };
}
