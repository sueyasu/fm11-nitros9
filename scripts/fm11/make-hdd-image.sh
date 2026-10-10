#!/bin/sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/common.sh"
ROOT=$(fm11_repo_root)
usage() { echo "usage: $0 m2230b|m2231b|m2232b|m2233b|m2234b|m2235b|m2241b|m2242b|m2243b" >&2; exit 2; }
MODEL=${1:-}
set -- $(fm11_hdd_geometry "$MODEL") || usage
CYL=$1; HEADS=$2; SPT=32; SECTOR_SIZE=256
TOTAL_SECTORS=$((CYL * HEADS * SPT)); SIZE=$((TOTAL_SECTORS * SECTOR_SIZE)); IMG="$ROOT/fm11-$MODEL.img"
rm -f "$IMG"; truncate -s "$SIZE" "$IMG"
ACTUAL=$(wc -c < "$IMG" | tr -d ' ')
[ "$ACTUAL" -eq "$SIZE" ] || { echo "HDD image size error: $ACTUAL (expected $SIZE)" >&2; exit 1; }
printf 'Created blank FM-11 HDD image: %s\n' "$IMG"
printf '  %s cylinders x %s heads x %s sectors x %s bytes = %s bytes\n' "$CYL" "$HEADS" "$SPT" "$SECTOR_SIZE" "$SIZE"
echo '  no IPL, boot track, RBF filesystem, or OS files are preinstalled'
