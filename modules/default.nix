self:

{
  commonConfigurations = import ./common.nix self;
  gravity = import ./gravity.nix;
  divi = import ./divi.nix;
  ivi = import ./ivi.nix;
  chinaRoute = import ./china-route.nix;
  chinaDNS = import ./china-dns.nix;
  localResolver = import ./local-resolver.nix;
  inadyn = import ./inadyn.nix;
  defaultHome = import ./home-common.nix;
}
