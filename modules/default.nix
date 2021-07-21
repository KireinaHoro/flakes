self:

{
  commonConfigurations = import ./common.nix self;
  gravity = import ./gravity.nix;
  divi = import ./divi.nix;
  ivi = import ./ivi.nix;
  chinaLocalNat = import ./china-local-nat.nix;
}
