self:

{
  commonConfigurations = import ./common.nix self;
  gravity = import ./gravity.nix;
  divi = import ./divi.nix;
  ivi = import ./ivi.nix;
  chinaRoute = import ./china-route.nix;
}
