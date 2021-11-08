final: prev: with final.lib;

{
  injectNetworkNames = mapAttrs (name: n: n // { inherit name; });
  injectNetdevNames = mapAttrs (Name: nd: recursiveUpdate nd { netdevConfig = { inherit Name; }; });

  nix-direnv = prev.nix-direnv.override { enableFlakes = true; };

  genIviMap = v4: v6: v4len: "map ${v4}/${toString v4len} ${v6}:${v4}/${toString (v4len + 96)}";
}
