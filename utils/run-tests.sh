#!/bin/sh

set -e

cd "$(dirname -- "$0")/.."

usage() {
cat << EOF
Usage:
  $1 docker [NIM VERSIONS...] - run in docker
  $1 nix [NIM VERSIONS...]    - run in nix-shell
EOF
exit 1
}

test_docker() {
	docker-compose build --build-arg NIM_VERSION=$nim_version
	docker-compose run --rm nimble test
}

test_nix() {
	rm -rf cache
	mkdir -p cache
	export XDG_RUNTIME_DIR=$PWD/cache

	export PGHOST=${PGHOST-localhost}

	nix-shell utils/shell.nix --argstr v "$nim_version" --run "nimble test"

	rm -rf cache
}

case "$1" in
d|docker) test_f=test_docker;;
n|nix) test_f=test_nix;;
*) usage "$0";;
esac
shift

[ "$#" = 0 ] && set -- 1.4.2 1.2.6 1.0.6

for nim_version in "$@";do
	printf "\x1b[1m%s\x1b[m\n" "$nim_version"
	"$test_f"
	printf "\n\n"
done

printf "\x1b[1;32mSuccessfully tested on %s %s\x1b[m\n" "$test_f" "$*"
