#!/bin/sh

set -e

cd "$(dirname -- "$0")/.."

[ "$#" = 0 ] && set -- git 0.20.2 0.19.6

for nim_version in "$@";do
	printf "\x1b[1m%s\x1b[m\n" "$nim_version"
	nix-shell utils/shell.nix --argstr v "$nim_version" --run "nimble test"
	printf "\n\n"
done
