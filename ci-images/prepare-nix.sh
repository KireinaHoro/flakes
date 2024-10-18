#!/bin/bash

set -eux

# start nix daemon
sudo nix daemon &

# sanity checks
id
pwd
ls -la
nix doctor

# run whatever is passed to us
"$@"
