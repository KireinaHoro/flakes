# Flakes collection by KireinaHoro

Per-host NixOS configuration is at `nixos/`.  Secrets are protected via
`sops-nix`.

Packages local to this flake are at `pkgs/` and are managed by `nvfetcher`.
Standalone ones not using `nvfetcher` should allow arbitrary arguments (for the
`source` parameter from `nvfetcher`).

## Updating

```shell
$ nix flake update
$ cd pkgs && nvfetcher build
```

The docker images for deploying over CI has the `kage` configuration built-in.
If too much stuff had changed, rebuild docker images.  This happens rather
infrequently (when the entire `nixpkgs` is updated) so it is not hooked up to
the CI.  Make sure that you are logged into the registry with `docker login`,
and that the current user has access to the docker daemon (part of `docker`
group).

```shell
$ cd ci-images
$ make
```

## Caveats

### Squid

Squid requires the cache dirs to be populated with `squid -z` before first
launch.  As on NixOS the configuration files are generated, use `systemctl
status squid` to find the location of the configuration file.  Use `nix shell
.#squid` to bring the `squid` binary into `PATH`.

### Blog

Remember to [update the lock file](https://t.me/c/1415471266/1015) for blog
input after updating the blog flake:

```bash
nix flake lock --update-input blog
deploy .#kage
```
