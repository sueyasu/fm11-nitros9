#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$DIR/../.." && pwd)
case "${1:-}" in
    6809|6309) exec "$ROOT/scripts/fm11/build-images.sh" 2 "$1" 2hd ;;
    *) echo "usage: $0 6809|6309" >&2; exit 2 ;;
esac
