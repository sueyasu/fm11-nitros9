#!/bin/sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/common.sh"
ROOT=$(CDPATH= cd -- "$DIR/../../.." && pwd)
CPU=${1:-}; MEDIA=${2:-all}
fm11_check_cpu "$CPU" || { echo "usage: $0 6809|6309 [2d|2hd|all]" >&2; exit 2; }
fm11_check_media "$MEDIA" || { echo "usage: $0 6809|6309 [2d|2hd|all]" >&2; exit 2; }
"$DIR/l1-build-cpu.sh" "$CPU"
"$DIR/l1-make-rbf.sh" "$CPU" "$MEDIA"
"$DIR/l1-make-d88.sh" "$CPU" "$MEDIA"
rename_one() {
    profile=$1
    for ext in rbf d88; do
        old="$ROOT/fm11-system-$CPU-$profile.$ext"; new="$ROOT/fm11-l1-$CPU-$profile.$ext"
        [ -f "$old" ] || { echo "Missing generated image: $old" >&2; exit 1; }
        mv -f "$old" "$new"
    done
}
case "$MEDIA" in 2d) rename_one 2d ;; 2hd) rename_one 2hd ;; all) rename_one 2d; rename_one 2hd ;; esac
