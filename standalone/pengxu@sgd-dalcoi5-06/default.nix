inputs:

{
  modules = [
    { nixpkgs.overlays = [ inputs.self.overlays.default ]; }

    ./home.nix
  ];
  extraSpecialArgs = {
    username = "pengxu";
    standalone = true;
  };
}
