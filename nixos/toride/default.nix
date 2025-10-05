{ self, nixpkgs, inputs }:

with nixpkgs;
lib.nixosSystem {
  system = "x86_64-linux";
  modules = with self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity
    { nixpkgs.overlays = [ self.overlays.default ]; }
    inputs.sops-nix.nixosModules.sops

    inputs.home-manager.nixosModules.home-manager
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
