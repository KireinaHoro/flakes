#!/bin/sh

# start nix daemon
sudo nix daemon &

nix flake lock --update-input $1
