#!/bin/sh

nix flake lock --update-input $1
