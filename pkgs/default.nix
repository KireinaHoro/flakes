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
    python39Packages.pelican = prev.python39Packages.pelican.overrideAttrs (oldAttrs: rec {
      patches = prev.writeText "jinja2-markupsafe.patch" ''
        --- source/pelican/utils.py     2021-08-01 18:33:58.588682264 +0800
        +++ source-new/pelican/utils.py 2021-08-01 18:33:43.398933115 +0800
        @@ -18,7 +18,7 @@

         import dateutil.parser

        -from jinja2 import Markup
        +from markupsafe import Markup

         import pytz

        diff -Naur source/pelican/writers.py source-new/pelican/writers.py
        --- source/pelican/writers.py   2021-08-01 18:34:10.770481673 +0800
        +++ source-new/pelican/writers.py       2021-08-01 18:33:43.398933115 +0800
        @@ -5,7 +5,7 @@

         from feedgenerator import Atom1Feed, Rss201rev2Feed, get_tag_uri

        -from jinja2 import Markup
        +from markupsafe import Markup

         from pelican.paginator import Paginator
         from pelican.plugins import signals

      '';
    });
  };
}
