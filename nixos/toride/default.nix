inputs:

{
  system = "x86_64-linux";
  modules = with inputs.self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix

    gravity
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
