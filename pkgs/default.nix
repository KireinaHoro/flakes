{ nixpkgs }:

with builtins;
with nixpkgs.lib;

let
  mapPackages = f: mapAttrs (name: _: { inherit name; value = f name; })
    (filterAttrs (k: v: v == "directory" && k != "_sources") (readDir ./.));
in {
  packages = pkgs: mapPackages (name: pkgs.${name});
  overlay = final: prev: mapPackages (name: let
    sources = (import ./_sources/generated.nix) { inherit (final) fetchurl fetchgit; };
    package = import (./. + "/${name}");
    args = intersectAttrs (functionArgs package) { source = sources.${name}; };
  in final.callPackage package args);
}
