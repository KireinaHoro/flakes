inputs:

{
  system = "x86_64-linux";
  modules = with inputs.self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity divi ivi
    inputs.sops-nix.nixosModules.sops

    inputs.simple-nixos-mailserver.nixosModule
  ];
}
