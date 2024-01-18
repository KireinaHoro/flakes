{ self, nixpkgs, inputs }:

inputs.nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    ./configuration.nix
    { nixpkgs.overlays = [ self.overlays.default ]; }
    inputs.home-manager.darwinModules.home-manager
    ./home.nix
  ];
}
