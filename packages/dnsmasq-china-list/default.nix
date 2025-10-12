{ source, pkgs, lib, server ? "114.114.114.114", accelAppleGoogle ? true }:

pkgs.stdenvNoCC.mkDerivation rec {
  inherit (source) pname version src;

  buildPhase = ''
    make dnsmasq SERVER=${server}
  '';

  installPhase = ''
    mkdir -p $out/dnsmasq
    ${if accelAppleGoogle then
      "mv *.dnsmasq.conf $out/dnsmasq"
      else
      "mv accelerated-domains.china.dnsmasq.conf $out/dnsmasq"
    }
  '';

  meta = with lib; {
    description = "Chinese-specific configuration to improve your favorite DNS server.";
    homepage = "https://github.com/felixonmars/dnsmasq-china-list";
    license = licenses.wtfpl;
  };
}
