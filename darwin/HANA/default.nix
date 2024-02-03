{ self, nixpkgs, inputs }:

inputs.nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = with self.nixosModules; [
    ./configuration.nix
    { nixpkgs.overlays = [ self.overlays.default ]; }

    inputs.home-manager.darwinModules.home-manager
    (defaultHome { username = "jsteward"; })
    ./home.nix
  ];
}
