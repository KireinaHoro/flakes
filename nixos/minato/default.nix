{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./configuration.nix
    ./hardware.nix
    { nixpkgs.overlays = [ self.overlay ]; }
  ];
}
