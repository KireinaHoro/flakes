{ self, nixpkgs, inputs }:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = with self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity divi ivi
    { nixpkgs.overlays = [ self.overlays.default inputs.blog.overlay ]; }
    inputs.sops-nix.nixosModules.sops

    inputs.simple-nixos-mailserver.nixosModule
  ];
}
