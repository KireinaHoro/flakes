{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = with self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity divi ivi chinaRoute chinaDNS localResolver
    { nixpkgs.overlays = [ self.overlays.default inputs.ranet.overlays.default ]; }
    inputs.sops-nix.nixosModules.sops
  ];
}
