#!/bin/bash

set -eux

# sanity checks
id
pwd
ls -la

# start nix daemon
sudo nix daemon &

nix flake lock --update-input $1
