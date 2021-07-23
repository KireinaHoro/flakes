{ source, pkgs, lib }:

pkgs.stdenv.mkDerivation rec {
  inherit (source) pname version src;

  server = "114.114.114.114";

  buildPhase = ''
    make dnsmasq SERVER=${server}
  '';

  installPhase = ''
    mkdir -p $out/dnsmasq
    mv *.dnsmasq.conf $out/dnsmasq
  '';

  meta = with lib; {
    description = "Chinese-specific configuration to improve your favorite DNS server.";
    homepage = "https://github.com/felixonmars/dnsmasq-china-list";
    license = licenses.wtfpl;
  };
}
