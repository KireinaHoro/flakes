{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = with self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity divi ivi chinaRoute chinaDNS
    { nixpkgs.overlays = [ self.overlay ]; }
    inputs.sops-nix.nixosModules.sops
  ];
}
