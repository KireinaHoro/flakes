{ self, nixpkgs, inputs }:

inputs.nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = with self.nixosModules; [
    ./configuration.nix
    { nixpkgs.overlays = [ self.overlays.default ]; }

    inputs.home-manager.darwinModules.home-manager
    {
      home-manager = {
        useUserPackages = true;
        useGlobalPkgs = true;
        users.jsteward = import ./home.nix;
        extraSpecialArgs = {
          inherit inputs;
          username = "jsteward";
          standalone = false;
        };
      };
    }
  ];
}
