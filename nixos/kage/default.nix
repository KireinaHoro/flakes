inputs:

{
  system = "x86_64-linux";
  modules = with inputs.self.nixosModules; [
    commonConfigurations
    ./configuration.nix
    ./hardware.nix
    ./networking.nix
    ./nutrition.nix

    gravity divi ivi
    inputs.sops-nix.nixosModules.sops
    inputs.mcp-nutrition-db.nixosModules.default
    inputs.openai-secure-tunnel-nix.nixosModules.default
  ];
}
