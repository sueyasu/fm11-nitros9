#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CPU=${1:-}
MEDIA=${2:-all}

# Keep the RBF builder and D88 writer as internal implementation helpers.
# This wrapper is the Level 1 counterpart of l2-build-floppy-image.sh and is
# the only floppy-image stage called by build-level1.sh.
"$DIR/l1-make-rbf.sh" "$CPU" "$MEDIA"
"$DIR/l1-make-d88.sh" "$CPU" "$MEDIA"
