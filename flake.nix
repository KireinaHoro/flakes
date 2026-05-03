{
  description = "KireinaHoro's Nix universe";

  inputs = rec {
    nixpkgs.url = "github:NixOS/nixpkgs";
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    ssh-to-pgp = { url = "github:Mic92/ssh-to-pgp"; inputs.nixpkgs.follows = "nixpkgs"; };
    flake-utils.url = "github:numtide/flake-utils";
    resume = {
      url = "github:KireinaHoro/resume";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
    blog = {
      url = "github:KireinaHoro/jsteward.moe";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        resume.follows = "resume";
      };
    };
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-darwin = { url = "github:LnL7/nix-darwin"; inputs.nixpkgs.follows = "nixpkgs"; };
    ranet = {
      url = "github:NickCao/ranet";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
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
    findConfsWithFilter = filter: f: decls: let
        allConfs = readDir decls;
        filteredConfs = filterAttrs (k: v: filter k && v == "directory") allConfs;
      in mapAttrs (k: _: f k (import (decls + "/${k}") inputs)) filteredConfs;
    findConfs = f: findConfsWithFilter (_: true) (_: conf: f conf);
    deployConfs = findConfsWithFilter
      (v: elem v [ "kage" "shigeru" "nagisa" "iori" "hama" ])
      (k: conf: {
        sshUser = "root";
        hostname = "${k}.jsteward.moe";
        profiles.system.path =
          inputs.deploy-rs.lib.${conf.system}.activate.nixos
            (nixosSystem conf);
      }) ./nixos;
    ourPkgDecls = import ./packages;
  in flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system: let
    pkgs = import nixpkgs { inherit system; };
  in rec {
    packages = (ourPkgDecls pkgs).packages;
    checks = inputs.deploy-rs.lib.${system}.deployChecks {
      nodes = pkgs.lib.filterAttrs (name: cfg: cfg.profiles.system.path.system == system) self.deploy.nodes;
    };
    devShells.default = with pkgs; mkShell {
      sources = attrValues self.inputs;
      # import sops keys
      sopsPGPKeyDirs = [ "./keys/hosts" "./keys/users" ];

      nativeBuildInputs = [
        inputs.sops-nix.packages.${system}.sops-import-keys-hook
        inputs.ssh-to-pgp.packages.${system}.ssh-to-pgp
        nvfetcher
        openssl
      ] ++ optional (!stdenv.isDarwin) inputs.deploy-rs.packages.${system}.deploy-rs;
    };
  }) // {
    nixosModules = import ./nixos-modules self;
    nixosConfigurations = findConfs nixosSystem ./nixos;
    darwinConfigurations = findConfs inputs.nix-darwin.lib.darwinSystem ./darwin;
    # all home-manager-only configurations are x86_64-linux
    homeConfigurations = findConfs (conf:
      inputs.home-manager.lib.homeManagerConfiguration
        (conf // { pkgs = nixpkgs.legacyPackages.x86_64-linux; })) ./standalone;
    deploy.nodes = deployConfs;
    overlays.default = composeManyExtensions [
      (import ./functions.nix)
      (final: prev: let
        our = ourPkgDecls prev;
      in {
        jstewardMoe = inputs.blog.packages.${prev.stdenvNoCC.hostPlatform.system}.default;
        vimPlugins = prev.vimPlugins // our.vimPlugins;
      } // our.packages)
      inputs.ranet.overlays.default
    ];
  };
}
