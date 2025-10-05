{ source, pkgs, lib }:

pkgs.stdenvNoCC.mkDerivation rec {
  inherit (source) pname version src;

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (ps: with ps; [ urwid ]))
  ];

  patchPhase = ''
    # weird uptime command, patch
    sed -i -e 's@uptime -p@uptime@g' myrktop.py
  '';

  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 myrktop.py $out/bin/myrktop
    patchShebangs $out/bin/myrktop
  '';

  meta = with lib; {
    description = "myrktop - Orange Pi 5 (RK3588) System Monitoring script CPU,RAM,NPU,GPU,TEMPERATURES";
    homepage = "https://github.com/mhl221135/myrktop";
    license = licenses.mit;
  };
}
