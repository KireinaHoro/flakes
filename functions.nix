final: prev: with final.lib;

rec {
  injectNetworkNames = mapAttrs (name: n: n // { inherit name; });
  injectNetdevNames = mapAttrs (Name: nd: recursiveUpdate nd { netdevConfig = { inherit Name; }; });

  genIviMap = v4: v6: v4len: "map ${v4}/${toString v4len} ${v6}:${v4}/${toString (v4len + 96)}";

  gravityHosts = mapAttrsToList (k: v: { v4 = "10.172.${k}.0"; v6 = "2a0c:b641:69c:${v.v6}4:0:4"; v6Len = v.len; })
    { "224" = { v6 = "ce1"; len = 60; };
      "176" = { v6 = "cb0"; len = 56; }; };
  gravityHostsExcept = v4: filter (h: h.v4 != v4) gravityHosts;

  ethzV4Addrs = [
    { prefix = "82.130.64.0"; len = 18; }
    { prefix = "192.33.96.0"; len = 21; }
    { prefix = "192.33.92.0"; len = 22; }
    { prefix = "192.33.91.0"; len = 24; }
    { prefix = "192.33.90.0"; len = 24; }
    { prefix = "192.33.87.0"; len = 24; }
    { prefix = "192.33.110.0"; len = 24; }
    { prefix = "192.33.108.0"; len = 23; }
    { prefix = "192.33.104.0"; len = 22; }
    { prefix = "148.187.192.0"; len = 19; }
    { prefix = "129.132.0.0"; len = 16; }
  ];
}
