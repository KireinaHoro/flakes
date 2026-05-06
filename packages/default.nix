pkgs:

with builtins;
with pkgs.lib;

let
  # All custom (mkDerivation) packages
  mapPackages = f: mapAttrs (name: _: f name)
    (filterAttrs (k: v: v == "directory" && k != "_sources") (readDir ./.));
  # All vim plugins that can be packaged automatically
  mapVimPlugins = f: listToAttrs (map (name: { inherit name; value = f name; }) [ "vim-ripgrep" "vim-haskell-indent" ]);

  # All sources from nvfetcher
  sources = import ./_sources/generated.nix {
    inherit (pkgs) fetchurl fetchgit fetchFromGitHub dockerTools;
  };

  a64pkgs = pkgs.pkgsCross.aarch64-multiplatform;
in {
  packages = mapPackages (name: let
    package = import (./. + "/${name}");
    args = intersectAttrs (functionArgs package) { source = sources.${name}; };
  in pkgs.callPackage package args) // rec {
    # create macOS bundle for darktable
    darktable-app = let
      icon = fetchurl {
        url = https://github.com/darktable-org/darktable/raw/refs/heads/master/packaging/macosx/Icons.icns;
        sha256 = "0xknckv85j1jiark6skvmd6pcy86dcim45jh319nh30q4rr6mjc1";
      };
    in pkgs.runCommand "darktable-app" {} ''
      mkdir -p $out/Applications/Darktable.app
      cd $out/Applications/Darktable.app

      mkdir -p Contents/MacOS
      cp ${pkgs.darktable}/bin/darktable Contents/MacOS/

      mkdir Contents/Resources
      cp ${icon} Contents/Resources/Icons.icns

      cat > Contents/Info.plist << EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>CFBundleDevelopmentRegion</key>
          <string>English</string>
          <key>CFBundleExecutable</key>
          <string>darktable</string>
          <key>CFBundleIconFile</key>
          <string>Icons.icns</string>
          <key>CFBundleIdentifier</key>
          <string>org.darktable</string>
          <key>CFBundleInfoDictionaryVersion</key>
          <string>6.0</string>
          <key>CFBundleName</key>
          <string>darktable</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleShortVersionString</key>
          <string>${pkgs.darktable.version}</string>
          <key>CFBundleSignature</key>
          <string>drkt</string>
          <key>CFBundleVersion</key>
          <string>${pkgs.darktable.version}</string>
          <key>NSPrincipalClass</key>
          <string>NSApplication</string>
          <key>CFBundleDocumentTypes</key>
          <array>
            <dict>
              <key>CFBundleTypeRole</key>
              <string>Viewer</string>
              <key>LSItemContentTypes</key>
              <array>
                <string>public.image</string>
                <string>public.directory</string>
              </array>
            </dict>
          </array>
        </dict>
      </plist>
      EOF
    '';

    # apply NickCao's ETX Babel patch
    bird2 = pkgs.bird2.overrideAttrs (old: rec {
      patches = old.patches ++ [ (fetchurl {
        url = https://github.com/NickCao/bird/commit/5567bdd85c0e8cbcd69122ae93909ee4e23c0f21.patch;
        sha256 = "0yy9rsj2k683wv1npjq6kipyxhc3qcmi8r60f8w3qky6jikik0yv";
      }) ];
    });

    # use 115200 baud rate for DDR binary
    rock5b-tpl = pkgs.rkbin.overrideAttrs (old: {
      nativeBuildInputs = with pkgs; [ python3 libfaketime ];

      installPhase = ''
        mkdir $out
        cp bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.18.bin $out/rock5b-tpl.bin

        sed -i -e '/uart baudrate=/s/$/115200/' tools/ddrbin_param.txt
        faketime -f '@1980-01-01 00:00:00 x0.001' \
          python3 tools/ddrbin_tool.py \
          rk3588 tools/ddrbin_param.txt $out/rock5b-tpl.bin
      '';
    });

    # use 115200 baud rate for ARM Trusted Firmware for iori
    rock5b-atf = a64pkgs.armTrustedFirmwareRK3588.overrideAttrs {
      patchPhase = ''
        sed -i '/^#define RK_DBG_UART_BAUDRATE/s/[0-9]\+$/115200/' plat/rockchip/rk3588/rk3588_def.h
      '';
    };

    # use 115200 baud rate for U-Boot for iori
    rock5b-uboot = a64pkgs.ubootRock5ModelB.overrideAttrs (old: {
      env = old.env // {
        BL31 = "${rock5b-atf}/bl31.elf";
        ROCKCHIP_TPL = "${rock5b-tpl}/rock5b-tpl.bin";
      };
      extraConfig = ''
        CONFIG_BAUDRATE=115200
      '';
    });
  };

  vimPlugins = mapVimPlugins (name: pkgs.vimUtils.buildVimPlugin { # vim plugins
    inherit name;
    inherit (sources."${name}") src;
  });
}
