#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo "make-test-hdd.sh is deprecated; using scripts/fm11/make-hdd-image.sh" >&2
exec "$ROOT/scripts/fm11/make-hdd-image.sh" "${1:-m2233b}"
