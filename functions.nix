final: prev: with final.lib;

rec {
  injectNetworkNames = mapAttrs (name: n: n // { inherit name; });
  injectNetdevNames = mapAttrs (Name: nd: recursiveUpdate nd { netdevConfig = { inherit Name; }; });

  genIviMap = v4: v6: v4Len:
    "map ${v4}/${toString v4Len} ${removeSuffix "::" v6}:${v4}/${toString (v4Len + 96)}";

  # host definitions
  gravityHosts = [
    # our nodes
    { name = "iori";    id = "cb0"; len = 56; remarks = "iWay (Zurich)"; }
    { name = "minato";  id = "cd0"; len = 56; remarks = "China Unicom (Beijing)"; }
    { name = "kage";    id = "ce0"; len = 60; remarks = "Vultr (Tokyo)"; }
    { name = "shigeru"; id = "ce1"; len = 60; remarks = "ETH VSOS (Zurich)"; }
    { name = "hama";    id = "ce2"; len = 60; remarks = "ETH ISGINF (Zurich)"; }
    { name = "nagisa";  id = "cf1"; len = 60; remarks = "Oracle Cloud (Zurich)"; }
    # listed only for generating mapping
    { name = "nick_sin";id = "f25"; len = 60; }
  ];
  # find host def by name
  gravityHostByName = name: f: f (head (filter (v: v.name == name) gravityHosts));
  gravityHostsExclude = names: f: map f (filter (v: !(elem v.name names)) gravityHosts);

  gravityHomePrefix = "2a0c:b641:69c";

  gravityHostToPrefix = {id, len, ...}: "${gravityHomePrefix}:${id}0::/${toString len}";
  gravityHostToIviPrefix4 = {id, len, ...}: let
    seg2 = toString (fromHexString (substring 0 1 id) + 160);
    seg3 = toString (fromHexString (substring 1 2 id));
  in { prefix = "10.${seg2}.${seg3}.0"; len = len - 36; };
  gravityHostToDiviPrefix = {id, len, ...}:
    { prefix = "${gravityHomePrefix}:${id}4:0:4::"; len = 96; };
  gravityHostToIviDestMap = h: let
    dp = gravityHostToDiviPrefix h;
  in {prefix, len}: genIviMap prefix dp.prefix len;

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
    # enzian blade machines
    { prefix = "10.111.1.0"; len = 24; }
  ];

  userToSops = user: with user; {
    owner = name;
    inherit group;
  };

  hostInV6Prefix = prefix: host: let
    parts = splitString "/" prefix;
    network = elemAt parts 0;
    len = elemAt parts 1;
  in "${network}${host}/${len}";
}
