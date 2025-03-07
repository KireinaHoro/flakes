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

## Checking if a (NixOS) host is up to date

The Git commit hash of the system configuration is recorded.  To check:

```console
$ cd /etc/nixos
$ git show $(nixos-version --configuration-revision)
```

If `git show` fails, it means that the system was built without a commit.  This
should be avoided (ideally the build should fail).

## Adding a new host

Install a new, regular NixOS host/VM with either the NixOS ISO or
`nixos-infect`.  Afterwards, clone the flakes repo, create the NixOS
configuration (based on an existing host), and switch to it:

```console
$ git clone git+ssh://github.com/KireinaHoro/flakes && cd flakes
$ # create nixos configuration for new host, and then:
$ sudo mv /etc/nixos{,.bak}
$ sudo ln -s $PWD /etc/nixos
$ sudo nixos-rebuild switch -L
```

The switching would partially fail due to missing keys for decrypting the sops
secret, but SSH should be up and thus have created the host key.  Add the host
key to `keys/hosts/` and enable sops for the new host:

```console
$ hostname=$(hostname -s)
$ fingerprint=$( { sudo cat /etc/ssh/ssh_host_rsa_key | ssh-to-pgp -i - -o keys/hosts/$hostname.asc; } 2>&1)
$ sed -i .sops.yaml \
> -e "/creation_rules/i\  - &$hostname $fingerprint" \
> -e "\$a\
> \   - path_regex: nixos/$hostname/secrets\\.yaml\$\n\
>     key_groups:\n\
>       - pgp:\n\
>         - *jsteward\n\
>         - *$hostname\n"
$
```

Finally, on a machine that we can plug the YubiKey into, create `secrets.yaml`
for the new machine by:

```console
$ sops nixos/<hostname>/secrets.yaml
```

We can then rebuild again with everything working.

## Blog

Blog deployment is triggered automatically with repository dispatch.  A new
commit in the [blog repo](https://github.com/KireinaHoro/jsteward.moe) will
trigger a flake lock update then the deploy action in this repo.
