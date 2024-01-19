{ pkgs, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "chnroute";
  version = "20210720";

  src = pkgs.fetchurl {
    url = "https://ftp.apnic.net/stats/apnic/2021/delegated-apnic-${version}.gz";
    sha256 = "sha256-3Y1EK47IVi1s7rasswSx6QmdS4x8pHX7HWBfZey0OJ4=";
  };

  buildInputs = [ pkgs.gawk ];

  dontUnpack = true;
  buildPhase = ''
    gzip -d < ${src} > input
    awk -F\| 'BEGIN { print "define chnv6_whitelist = {" } /CN\|ipv6/ { printf("  %s/%d,\n", $4, $5) } END { print "}" }' input > chnroute-v6
    awk -F\| 'BEGIN { print "define chnv4_whitelist = {" } /CN\|ipv4/ { printf("  %s/%d,\n", $4, 32-log($5)/log(2)) } END { print "}" }' input > chnroute-v4
  '';
  installPhase = ''
    mkdir $out
    mv chnroute-v{4,6} $out
  '';
}
