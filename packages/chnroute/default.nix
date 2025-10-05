{ pkgs, ... }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "chnroute";
  version = "20251004";

  src = pkgs.fetchurl {
    url = let
      year = builtins.substring 0 4 version;
    in "https://ftp.apnic.net/stats/apnic/${year}/delegated-apnic-${version}.gz";
    sha256 = "sha256-gv4sA5tvnWosiSH5CrvhmfWL89p+DVJb3s3AYye0HgM=";
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
