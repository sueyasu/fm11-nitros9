#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
case "${1:-}" in
    6809|6309|all) exec "$DIR/build-floppy-image.sh" "$1" 2hd ;;
    *) echo "usage: $0 6809|6309|all" >&2; exit 2 ;;
esac
