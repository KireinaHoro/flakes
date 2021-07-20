{ nixpkgs }:

with builtins;
with nixpkgs.lib;

let
  mapPackages = f: mapAttrs (name: _: f name)
    (filterAttrs (k: v: v == "directory" && k != "_build") (readDir ./.));
in {
  packages = pkgs: mapPackages (name: pkgs.${name});
  overlay = final: prev: mapPackages (name: let
    sources = import ./sources.nix { inherit (final) fetchurl fetchgit; };
    package = import (./. + "/${name}");
    args = intersectAttrs (functionArgs package) { source = sources.${name}; };
  in final.callPackage package args);
}
