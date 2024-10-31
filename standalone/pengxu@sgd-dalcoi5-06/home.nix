{ config, lib, pkgs, ... }:

let
  username = "pengxu";
  homeDirectory = "/local/home/${username}";
  workDir = "${homeDirectory}/work-local";
  verilatorRoot = "${workDir}/verilator";
  xdgConfigHome = "${homeDirectory}/.config_ubuntu_22.04";
in

{
  nixpkgs.config.allowUnfree = true;
  programs.vscode.enable = true;

  home = {
    inherit username homeDirectory;
    sessionVariables = {
      VERILATOR_ROOT = verilatorRoot;
    };
    sessionPath = [
      "${verilatorRoot}/install/bin"
    ];

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
      # spinalhdl formal
      symbiyosys
      yices
      rustup
      typst pdf2svg
    ];
  };
}
