inputs:

{
  system = "aarch64-linux";
  modules = with inputs.self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity divi ivi chinaRoute chinaDNS localResolver
    inputs.sops-nix.nixosModules.sops
  ];
}
