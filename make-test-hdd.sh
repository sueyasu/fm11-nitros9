#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SECTOR=256
RESERVED=19
TYPE=${1:-m2233b}

case "$TYPE" in
    m2231b) CYL=157; HEADS=4 ;;
    m2230b) CYL=315; HEADS=2 ;;
    m2232b) CYL=157; HEADS=6 ;;
    m2233b) CYL=315; HEADS=4 ;;
    m2234b) CYL=315; HEADS=6 ;;
    m2235b) CYL=315; HEADS=8 ;;
    m2241b) CYL=747; HEADS=4 ;;
    m2242b) CYL=747; HEADS=7 ;;
    m2243b) CYL=747; HEADS=11 ;;
    *)
        echo "usage: $0 [m2231b|m2230b|m2232b|m2233b|m2234b|m2235b|m2241b|m2242b|m2243b]" >&2
        exit 2
        ;;
esac

SPT=32
SECTORS=$((CYL*HEADS*SPT))
RBFSECTORS=$((SECTORS-RESERVED))
SIZE=$((SECTORS*SECTOR))
IMG="$ROOT/fm11-$TYPE-h0.hdd"
TMP=$(mktemp "${TMPDIR:-/tmp}/fm11-hdd-rbf.XXXXXX")
trap 'rm -f "$TMP"' EXIT HUP INT TERM

if ! command -v os9 >/dev/null 2>&1; then
    echo "ToolShed 'os9' command is required" >&2
    exit 1
fi

rm -f "$IMG"
os9 format -e -l"$RBFSECTORS" -bs"$SECTOR" -q "$TMP" -n"FM11H0"
truncate -s "$SIZE" "$IMG"
dd if="$TMP" of="$IMG" bs="$SECTOR" seek="$RESERVED" conv=notrunc status=none
actual=$(wc -c < "$IMG" | tr -d ' ')
if [ "$actual" -ne "$SIZE" ]; then
    echo "HDD image size error: $actual (expected $SIZE)" >&2
    exit 1
fi
printf 'Created %s: %s cylinders x %s heads x %s sectors x %s bytes = %s bytes\n' \
    "$IMG" "$CYL" "$HEADS" "$SPT" "$SECTOR" "$SIZE"
printf 'Reserved physical sectors 0-%s; RBF LSN0 begins at physical sector %s.\n' \
    $((RESERVED-1)) "$RESERVED"
