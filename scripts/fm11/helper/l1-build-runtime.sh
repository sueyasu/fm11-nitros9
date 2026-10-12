#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CPU=${1:-}
[ -n "$CPU" ] || { echo "usage: $0 6809|6309" >&2; exit 2; }

FM11_BUILD_PHASE=runtime exec "$DIR/l1-build-common.sh" "$CPU"
