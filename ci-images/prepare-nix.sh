#!/bin/bash

set -eux

# start nix daemon
nohup sh -c 'sudo nix daemon &' && sleep 1

# sanity checks
id
pwd
ls -la
nix config check

# run whatever is passed to us
# we pass the entire script in one argument, use eval
eval "$@"
