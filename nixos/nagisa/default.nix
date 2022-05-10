{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = with self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity
    { nixpkgs.overlays = [ self.overlay ]; }
    inputs.sops-nix.nixosModules.sops
  ];
}
