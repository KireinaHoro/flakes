final: prev: with final.lib;

{
  injectNetworkNames = mapAttrs (name: n: n // { inherit name; });
  injectNetdevNames = mapAttrs (Name: nd: recursiveUpdate nd { netdevConfig = { inherit Name; }; });

  nix-direnv = prev.nix-direnv.override { enableFlakes = true; };
}
