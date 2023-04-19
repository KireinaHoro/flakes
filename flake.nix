{
  description = "KireinaHoro's Nix universe";

  inputs = rec {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    flake-utils.url = "github:numtide/flake-utils";
    blog = {
      url = "github:KireinaHoro/jsteward.moe";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
  with builtins;
  with nixpkgs.lib;
  let
    this = import ./pkgs { inherit nixpkgs; };
  in flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        inputs.deploy-rs.overlay
        inputs.sops-nix.overlays.default
        inputs.blog.overlay
        self.overlays.default
      ];
    };
  in rec {
    packages = this.packages pkgs;
    checks = packages // (inputs.deploy-rs.lib.${system}.deployChecks {
      nodes = pkgs.lib.filterAttrs (name: cfg: cfg.profiles.system.path.system == system) self.deploy.nodes;
    });
    legacyPackages = pkgs;
    devShell = with pkgs; mkShell {
      sources = attrValues self.inputs;
      # import sops keys
      sopsPGPKeyDirs = [ "./keys/hosts" "./keys/users" ];

      nativeBuildInputs = [
        deploy-rs.deploy-rs
        sops-import-keys-hook
      ];
    };
  }) // {
    nixosModules = import ./modules self;
    overlays.default = final: prev: nixpkgs.lib.composeExtensions this.overlay (import ./functions.nix) final prev;
    nixosConfigurations =
      mapAttrs (k: _: import (./nixos + "/${k}") { inherit self nixpkgs inputs; }) (readDir ./nixos);
    deploy.nodes = genAttrs [ "kage" "shigeru" "nagisa" ] (n: {
      sshUser = "root";
      hostname = "${n}.jsteward.moe";
      profiles.system.path =
        inputs.deploy-rs.lib.${self.nixosConfigurations.${n}.pkgs.system}.activate.nixos self.nixosConfigurations.${n};
    });
  };
}
