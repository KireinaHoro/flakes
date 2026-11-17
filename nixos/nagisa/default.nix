inputs:

{
  system = "x86_64-linux";
  modules = with inputs.self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity
    inputs.sops-nix.nixosModules.sops
  ];
}
