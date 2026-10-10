#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

for cpu in 6809 6309; do
    echo "============================================================"
    echo "Building FM-11 NitrOS-9 Level 1 for $cpu"
    echo "============================================================"
    "$ROOT/scripts/fm11/build-images.sh" 1 "$cpu"
done

echo
echo "Created bootable FD images:"
echo "  fm11-l1-6809-2d.d88"
echo "  fm11-l1-6809-2hd.d88"
echo "  fm11-l1-6309-2d.d88"
echo "  fm11-l1-6309-2hd.d88"
