{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = with self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity
    { nixpkgs.overlays = [ self.overlays.default ]; }
    inputs.sops-nix.nixosModules.sops

    { _module.args = { inherit inputs; }; }

    inputs.home-manager.nixosModules.home-manager
    (defaultHome { username = "jsteward"; })
    ./home.nix
  ];
}
