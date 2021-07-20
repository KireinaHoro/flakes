self:

{
  commonConfigurations = import ./common.nix self;
  gravity = import ./gravity.nix;
  divi = import ./divi.nix;
}
