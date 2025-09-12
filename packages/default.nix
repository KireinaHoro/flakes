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
      a64pkgs = prev.pkgsCross.aarch64-multiplatform;
    in mapPackages (name: let
      package = import (./. + "/${name}");
      args = intersectAttrs (functionArgs package) { source = sources.${name}; };
    in final.callPackage package args) // rec {
      # override existing packages
      tayga = prev.tayga.overrideAttrs (oldAttrs: rec {
        patches = getDebianPatches (fetchTarball {
          url = http://deb.debian.org/debian/pool/main/t/tayga/tayga_0.9.2-8.debian.tar.xz;
          sha256 = "17lq6ddildf0lw2zwsp89d6vgqds4m53jq8syh4hbcwmps3dhgc5";
        });
      });
      bird2 = prev.bird2.overrideAttrs (oldAttrs: rec {
        # apply NickCao's ETX Babel patch
        patches = oldAttrs.patches ++ [ (fetchurl {
          url = https://github.com/NickCao/bird/commit/5567bdd85c0e8cbcd69122ae93909ee4e23c0f21.patch;
          sha256 = "0yy9rsj2k683wv1npjq6kipyxhc3qcmi8r60f8w3qky6jikik0yv";
        }) ];
      });

      # use 115200 baud rate for DDR binary
      rock5b-tpl = prev.rkbin.overrideAttrs (oldAttrs: {
        installPhase = ''
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" tools/ddrbin_tool
          sed -i -e '/uart baudrate=/s/$/115200/' tools/ddrbin_param.txt
          tools/ddrbin_tool rk3588 tools/ddrbin_param.txt bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.18.bin
          mkdir $out
          cp bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.18.bin $out/rock5b-tpl.bin
        '';
      });

      # use 115200 baud rate for ARM Trusted Firmware for iori
      rock5b-atf = a64pkgs.armTrustedFirmwareRK3588.overrideAttrs {
        patchPhase = ''
          sed -i '/^#define RK_DBG_UART_BAUDRATE/s/[0-9]\+$/115200/' plat/rockchip/rk3588/rk3588_def.h
        '';
      };

      # use 115200 baud rate for U-Boot for iori
      rock5b-uboot = a64pkgs.ubootRock5ModelB.overrideAttrs {
        BL31 = "${rock5b-atf}/bl31.elf";
        ROCKCHIP_TPL = "${rock5b-tpl}/rock5b-tpl.bin";
        extraConfig = ''
          CONFIG_BAUDRATE=115200
        '';
      };
    } // (let
      newPlugins = mapVimPlugins (name: final.vimUtils.buildVimPlugin { # vim plugins
          inherit name;
          inherit (sources."${name}") src;
        });
    in { vimPlugins = prev.vimPlugins // newPlugins; });
}
