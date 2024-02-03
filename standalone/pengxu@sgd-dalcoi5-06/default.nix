{ self, nixpkgs, inputs }:

inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = with self.nixosModules; [
    { nixpkgs.overlays = [ self.overlays.default ]; }

    (defaultHome { username = "pengxu"; standalone = true; })
    ./home.nix
  ];
}
