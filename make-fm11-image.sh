#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CPU=${1:-}
case "$CPU" in
    6809|6309) ;;
    *) echo "usage: $0 6809|6309 [all|2d|2hd]" >&2; exit 2 ;;
esac
shift
OUT="$ROOT/level1/fm11/build-minimal-$CPU"

usage() {
    echo "usage: $0 6809|6309 [all|2d|2hd]" >&2
    exit 2
}

MODE=${1:-all}
case "$MODE" in
    all|2d|2hd) ;;
    *) usage ;;
esac

make_image() {
    profile=$1
    case "$profile" in
        2d)
            rbf="$ROOT/fm11-system-$CPU-2d.rbf"
            d88="$ROOT/fm11-system-$CPU-2d.d88"
            ipl="$OUT/ipl-2d.bin"
            bt="$OUT/boottrack-2d.bin"
            ;;
        2hd)
            rbf="$ROOT/fm11-system-$CPU-2hd.rbf"
            d88="$ROOT/fm11-system-$CPU-2hd.d88"
            ipl="$OUT/ipl-2hd.bin"
            bt="$OUT/boottrack-2hd.bin"
            ;;
        *) exit 2 ;;
    esac

    for f in "$rbf" "$ipl" "$bt"; do
        [ -f "$f" ] || {
            echo "Missing $f" >&2
            echo "Run ./build-cpu.sh $CPU and ./make-test-disk.sh $CPU first." >&2
            exit 1
        }
    done

    # Keep the ToolShed-editable .rbf as the master.  Apply the FM-11
    # descriptor geometry only to a private temporary copy, then feed that
    # directly into the D88 writer.  No persistent intermediate .img exists.
    rbftmp=$(mktemp)
    trap 'rm -f "$rbftmp"' EXIT INT TERM
    cp "$rbf" "$rbftmp"
    "$ROOT/patch-boot-descriptor.py" "$rbftmp"
    "$ROOT/patch-rbf-floppy.py" "$rbftmp" "$profile"

    tmpd88="$d88.tmp.$$"
    rm -f "$tmpd88"
    python3 "$ROOT/make-d88.py" "$profile" "$rbftmp" "$ipl" "$bt" "$tmpd88"
    mv "$tmpd88" "$d88"

    rm -f "$rbftmp"
    trap - EXIT INT TERM
    echo "Created FM-11 D88 image: $d88"
}

case "$MODE" in
    2d) make_image 2d ;;
    2hd) make_image 2hd ;;
    all) make_image 2d; make_image 2hd ;;
esac
