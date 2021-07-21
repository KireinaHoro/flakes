# Flakes collection by KireinaHoro

Per-host NixOS configuration is at `nixos/`.  Secrets are protected via `sops-nix`.

Packages local to this flake are at `pkgs/` and are managed by `nvfetcher`.  Standalone ones not using `nvfetcher` should allow arbitrary arguments (for the `source` parameter from `nvfetcher`).

**Note**: due to a limitation in Nix flakes, it is not possible to `input` this flake in other flakes (without duplicating all the `follows`; see [this pull request](https://github.com/NixOS/nix/pull/4641)).
