rev: {
  commonConfigurations = import ./common.nix rev;
  gravity = import ./gravity.nix;
  divi = import ./divi.nix;
  ivi = import ./ivi.nix;
  chinaRoute = import ./china-route.nix;
  chinaDNS = import ./china-dns.nix;
  localResolver = import ./local-resolver.nix;
}
