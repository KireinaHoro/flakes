{
  description = "nix drv set by KireinaHoro";

  inputs = rec {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    sops-nix.url = "github:Mic92/sops-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
  with builtins;
  with nixpkgs.lib;
  let
    this = import ./pkgs { inherit nixpkgs; };
  in flake-utils.lib.eachSystem [ "x86_64-linux" ] (system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ inputs.deploy-rs.overlay ];
    };
  in rec {
    packages = this.packages pkgs // { deploy-rs = pkgs.deploy-rs.deploy-rs; };
    checks = packages // (inputs.deploy-rs.lib.${system}.deployChecks {
      nodes = pkgs.lib.filterAttrs (name: cfg: cfg.profiles.system.path.system == system) self.deploy.nodes;
    });
    legacyPackages = pkgs;
    devShell = with pkgs; mkShell {
      nativeBuildInputs = [ deploy-rs.deploy-rs ];
    };
  }) // {
    nixosModules = import ./modules;
    overlay = this.overlay;
    nixosConfigurations =
      mapAttrs (k: _: import (./nixos + "/${k}") { inherit self nixpkgs inputs; }) (readDir ./nixos);
    deploy.nodes = {};
  };
}
