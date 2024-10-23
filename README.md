# Flakes collection by KireinaHoro

Per-host NixOS configuration is at `nixos/`.  Secrets are protected via
`sops-nix`.

Packages local to this flake are at `pkgs/` and are managed by `nvfetcher`.
Standalone ones not using `nvfetcher` should allow arbitrary arguments (for the
`source` parameter from `nvfetcher`).

## Updating

```console
$ nix flake update
$ cd pkgs && nvfetcher build
```

The docker images for deploying over CI has the `kage` configuration built-in.
If too much stuff had changed, rebuild docker images.  This happens rather
infrequently (when the entire `nixpkgs` is updated) so it is not hooked up to
the CI.  Make sure that you are logged into the registry with `docker login`,
and that the current user has access to the docker daemon (part of `docker`
group).

```console
$ cd ci-images
$ make
```

## Adding a new host

Install a new, regular NixOS host/VM with either the NixOS ISO or
`nixos-infect`.  Afterwards, clone the flakes repo, add the host key to
`keys/hosts/` and enable sops for the new host:

```console
$ git clone git+ssh://github.com/KireinaHoro/flakes && cd flakes
$ hostname=$(hostname -s)
$ fingerprint=$( { sudo cat /etc/ssh/ssh_host_rsa_key | ssh-to-pgp -i - -o keys/hosts/$hostname.asc; } 2>&1)
$ sed -i .sops.yaml \
> -e "/creation_rules/i\  - &$hostname $fingerprint" \
> -e "\$a\
>   - path_regex: nixos/$hostname/secrets\\.yaml\$\n\
>     key_groups:\n\
>       - pgp:\n\
>         - *jsteward\n\
>         - *$hostname\n"
```

Then, create the NixOS configuration for the host and rebuild with flake:

```console
$ # create nixos configuration for new host, and then:
$ sudo mv /etc/nixos{,.bak}
$ sudo ln -s $PWD /etc/nixos
$ sudo nixos-rebuild switch -L
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
