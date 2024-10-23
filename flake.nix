{
  description = "KireinaHoro's Nix universe";

  inputs = rec {
    nixpkgs.url = "github:NixOS/nixpkgs";
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    ssh-to-pgp = { url = "github:Mic92/ssh-to-pgp/1.1.2"; inputs.nixpkgs.follows = "nixpkgs"; };
    flake-utils.url = "github:numtide/flake-utils";
    blog = {
      url = "github:KireinaHoro/jsteward.moe";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    rock5b-nixos = { url = "github:KireinaHoro/rock5b-nixos"; inputs.nixpkgs.follows = "nixpkgs"; };
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-darwin = { url = "github:LnL7/nix-darwin"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
  with builtins;
  with nixpkgs.lib;
  let
    this = import ./packages { inherit nixpkgs; };
    findConfs = typeDir: mapAttrs (k: _: import (typeDir + "/${k}") { inherit self nixpkgs inputs; }) (readDir typeDir);
  in flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
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
    devShells.default = with pkgs; mkShell {
      sources = attrValues self.inputs;
      # import sops keys
      sopsPGPKeyDirs = [ "./keys/hosts" "./keys/users" ];

      nativeBuildInputs = [
        inputs.deploy-rs.packages.${system}.deploy-rs
        inputs.sops-nix.packages.${system}.sops-import-keys-hook
        inputs.ssh-to-pgp.packages.${system}.ssh-to-pgp
        nvfetcher
        rait
      ];
    };
  }) // {
    nixosModules = import ./modules self;
    overlays.default = final: prev: nixpkgs.lib.composeExtensions this.overlay (import ./functions.nix) final prev;
    nixosConfigurations = findConfs ./nixos;
    darwinConfigurations = findConfs ./darwin;
    homeConfigurations = findConfs ./standalone;
    deploy.nodes = genAttrs [ "kage" "shigeru" "nagisa" "iori" ] (n: {
      sshUser = "root";
      hostname = "${n}.jsteward.moe";
      profiles.system.path =
        inputs.deploy-rs.lib.${self.nixosConfigurations.${n}.pkgs.system}.activate.nixos self.nixosConfigurations.${n};
    });
  };
}
