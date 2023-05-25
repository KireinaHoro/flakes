{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = with self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity
    { nixpkgs.overlays = [ self.overlays.default ]; }
    inputs.sops-nix.nixosModules.sops

    inputs.rock5b-nixos.nixosModules.apply-overlay
    inputs.rock5b-nixos.nixosModules.kernel
  ];
}
