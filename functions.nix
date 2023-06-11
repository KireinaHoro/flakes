final: prev: with final.lib;

rec {
  injectNetworkNames = mapAttrs (name: n: n // { inherit name; });
  injectNetdevNames = mapAttrs (Name: nd: recursiveUpdate nd { netdevConfig = { inherit Name; }; });

  nix-direnv = prev.nix-direnv.override { enableFlakes = true; };

  genIviMap = v4: v6: v4len: "map ${v4}/${toString v4len} ${v6}:${v4}/${toString (v4len + 96)}";

  gravityHosts = mapAttrsToList (k: v: { v4 = "10.172.${k}.0"; v6 = "2a0c:b641:69c:${v.v6}4:0:4"; v6Len = v.len; })
    { "224" = { v6 = "ce1"; len = 60; };
      "176" = { v6 = "cb0"; len = 56; }; };
  gravityHostsExcept = v4: filter (h: h.v4 != v4) gravityHosts;
}
