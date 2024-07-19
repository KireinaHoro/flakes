FROM nixos/nix

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
RUN nix-channel --update
RUN nix-env -iA nixpkgs.openssh
RUN nix-env -iA nixpkgs.git
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# build flake so that we can save some time deploying minor changes
RUN nix build github:KireinaHoro/flakes\#nixosConfigurations.kage.config.system.build.toplevel

COPY deploy.sh /
COPY flake-lock.sh /
