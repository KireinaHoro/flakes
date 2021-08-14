FROM nixos/nix

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
RUN nix-channel --update
RUN nix-env -iA nixpkgs.nixUnstable
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

COPY deploy.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
