self: { config, pkgs, lib, ... }:

{
  networking.domain = "jsteward.moe";

  users.users.jsteward = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCoZdntY4uf9cnvIxy2aLE6URgzVTp5wLMBCU+HAq9e2t28GkgEl/QSr1K3aloGZ411YcbvQNv5yqx6tmrZjaOixefC6JKXU9agBNVZvhE6AUHNT3U97kmOiyEL3/HY2hGP9cR8sIfErI27+4a1W778CA6ARkBegvhWZ3NlwSol+RnR710x4lH6m7BsW2a9u/PC8JJPo2PJJrIjw7H8OcPUSZScE9/ztragghWhzdU+2Wsw/vwOdQDzg05518Xv+X92zc25F9CW/QD1f3DM0lonscljfHPvPazU7P7Px88o+W8d1Sik7bPwvct8Ce4iKcn0s4GNpbIoBVLdsrbdcrrM9Ge7ba/3UYRPkiTze3TLyrKJAAGtZ/lnXBBMhAzZxKVLairmhf/UZzaFYYTht7iDwXfAZCaZbz18yDOnj6zeGR97ZEhNlgFdF6z3AfYaTPLTYdKMUL41rpbj8Ipawg9tg7amcRZ/sdlepq6e47wUZv7f2h1z+xA4afSCMbDi/VjyIi918iymKLZX28CDvaAUJFoLus0JTenVGZ/xJx9Ngi+YOfBVnpP95xG9kW9kl0FR4KBdcOOC+folad69gFFOyi/GNaZO/k/zr+gf67P3TDm1yVkakF9Ey5qb8lD4ACtWTVIolUcrRhbYJJ9Su0uhS7wo+izXz7waAXHrRdyC5Q== cardno:000606940203"
    ];
  };
  services.openssh.enable = true;

  system.configurationRevision = if self ? rev then self.rev else "dirty";

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    gc = { automatic = true; dates = "03:15"; };
  };

  environment.systemPackages = with pkgs; [
    vim wget tmux htop ripgrep bat git
  ];
  environment.variables.EDITOR = "vim";

  systemd.network.enable = true;
  systemd.services."systemd-networkd-wait-online".enable = false;
}
