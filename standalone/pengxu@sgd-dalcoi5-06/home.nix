{ config, pkgs, ... }:

let
  username = "pengxu";
  homeDirectory = "/local/home/${username}";
  verilatorRoot = "${homeDirectory}/work-local/verilator";
in

{
  home = {
    inherit username homeDirectory;
    sessionVariables = {
      VERILATOR_ROOT = verilatorRoot;
    };
    sessionPath = [
      "${homeDirectory}/.local/bin/" # XXX: express with XDG?
      "${verilatorRoot}/install/bin"
    ];

    file."${config.xdg.configHome}/nix/nix.conf".text = ''
      experimental-features = nix-command flakes ca-derivations
    '';
  };
}
