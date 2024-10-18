#!/bin/bash

set -eux

# sanity checks
id
pwd
ls -la

# start nix daemon
sudo nix daemon &

keyfile=privkey

echo "$2" > $keyfile
chmod 400 $keyfile

# we assume that the target flake has the deploy-rs package available
nix run $1#deploy-rs.deploy-rs -- --ssh-opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $keyfile" $1#$3
