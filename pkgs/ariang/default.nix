{ source, pkgs, lib }: let
  nodeDependencies = (pkgs.callPackage source.src { nodejs = pkgs."nodejs-14_x"; }).shell.nodeDependencies;
in

pkgs.stdenv.mkDerivation rec {
  inherit (source) pname version src;

  buildInputs = with pkgs; [ nodePackages.gulp ];
  buildPhase = ''
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"
    gulp clean build
  '';
  installPhase = ''
    mkdir -p $out
    mv dist $out
  '';
}
