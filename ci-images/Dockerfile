FROM nixos/nix

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
RUN nix-channel --update
RUN nix-env -iA nixpkgs.openssh
RUN nix-env -iA nixpkgs.git
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

COPY deploy.sh /
COPY flake-lock.sh /
