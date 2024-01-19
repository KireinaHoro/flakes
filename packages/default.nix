{ nixpkgs }:

with builtins;
with nixpkgs.lib;

let
  mapPackages = f: mapAttrs (name: _: f name)
    (filterAttrs (k: v: v == "directory" && k != "_sources") (readDir ./.));
  getDebianPatches = p: map (x: p + "/patches/${x}")
    (filter (x: x != "") (splitString "\n" (readFile (p + "/patches/series"))));
  mapVimPlugins = f: listToAttrs (map (name: { inherit name; value = f name; }) [ "vim-ripgrep" "vim-haskell-indent" ]);
in {
  # collect flakes output packages from nixpkgs overlay
  packages = pkgs: mapPackages (name: pkgs.${name}) // mapVimPlugins (name: pkgs.vimPlugins.${name});
  overlay = final: prev: let
      sources = import ./_sources/generated.nix { inherit (final) fetchurl fetchgit fetchFromGitHub dockerTools; };
    in mapPackages (name: let
      package = import (./. + "/${name}");
      args = intersectAttrs (functionArgs package) { source = sources.${name}; };
    in final.callPackage package args) // {
      # override existing packages
      tayga = prev.tayga.overrideAttrs (oldAttrs: rec {
        version = "0.9.2-8";
        patches = getDebianPatches (fetchTarball {
          url = http://deb.debian.org/debian/pool/main/t/tayga/tayga_0.9.2-8.debian.tar.xz;
          sha256 = "17lq6ddildf0lw2zwsp89d6vgqds4m53jq8syh4hbcwmps3dhgc5";
        });
      });
    } // (let
      newPlugins = mapVimPlugins (name: final.vimUtils.buildVimPlugin { # vim plugins
          inherit name;
          inherit (sources."${name}") src;
        });
    in { vimPlugins = prev.vimPlugins // newPlugins; });
}
