{ source, pkgs, lib }:

pkgs.stdenv.mkDerivation rec {
  inherit (source) pname version src;

  installPhase = ''
    mkdir -p $out
    mv dnsmasq/ $out
  '';

  meta = with lib; {
    description = "The NoTracking blocklist is a DNS based filter list for blocking ads, malware, phising and other online garbage.";
    homepage = "https://github.com/notracking/hosts-blocklists";
  };
}
