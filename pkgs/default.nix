{ nixpkgs }:

with builtins;
with nixpkgs.lib;

let
  mapPackages = f: mapAttrs (name: _: f name)
    (filterAttrs (k: v: v == "directory" && k != "_build") (readDir ./.));
  getDebianPatches = p: map (x: p + "/patches/${x}")
    (filter (x: x != "") (splitString "\n" (readFile (p + "/patches/series"))));
in {
  packages = pkgs: mapPackages (name: pkgs.${name});
  overlay = final: prev: mapPackages (name: let
    sources = import ./sources.nix { inherit (final) fetchurl fetchgit; };
    package = import (./. + "/${name}");
    args = intersectAttrs (functionArgs package) { source = sources.${name}; };
  in final.callPackage package args)
  // {
    tayga = prev.tayga.overrideAttrs (oldAttrs: rec {
      version = "0.9.2-8";
      patches = getDebianPatches (fetchTarball {
        url = http://deb.debian.org/debian/pool/main/t/tayga/tayga_0.9.2-8.debian.tar.xz;
        sha256 = "17lq6ddildf0lw2zwsp89d6vgqds4m53jq8syh4hbcwmps3dhgc5";
      });
    });
  };
}
