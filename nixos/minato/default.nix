{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    self.nixosModules.commonConfigurations
    ./configuration.nix
    ./hardware.nix
    { nixpkgs.overlays = [ self.overlay ]; }
    inputs.sops-nix.nixosModules.sops
  ];
}
