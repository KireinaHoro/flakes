FROM alpine:latest

# install dependencies
# use bash for scripts since the alpine sh is weird af
RUN apk add --no-cache openssh git nix sudo bash

# add a user with id 1001 to match permissions with the github env
RUN adduser -u 1001 -D github && \
    adduser github wheel && \
    adduser github nix && \
    mkdir -p /github/home && \
    chown -R github:github /github && \
    ln -s /github/home /home/github

# set up Nix command and flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# allow user to run sudo without password
RUN echo "%wheel  ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# run commands as the github user by default
USER 1001

# build flake and deploy tool so that we can save some time deploying minor changes
RUN cd && nohup sh -c 'sudo nix daemon &' && sleep 1 && \
    nix build github:KireinaHoro/flakes\#nixosConfigurations.kage.config.system.build.toplevel && \
    nix run github:KireinaHoro/flakes\#deploy-rs.deploy-rs -- --version

COPY prepare-nix.sh /
ENTRYPOINT ["prepare-nix.sh"]
