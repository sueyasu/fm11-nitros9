#!/bin/sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/helper/common.sh"
usage() { echo "usage: $0 1|2 6809|6309 [2d|2hd|all]" >&2; exit 2; }
LEVEL=$(fm11_level_name "${1:-}") || usage
CPU=${2:-}
MEDIA=${3:-all}
fm11_check_cpu "$CPU" || usage
fm11_check_media "$MEDIA" || usage
case "$LEVEL" in
    1) "$DIR/helper/build-level1.sh" "$CPU" "$MEDIA" ;;
    2) "$DIR/helper/build-level2.sh" "$CPU" "$MEDIA" ;;
esac
echo
echo "FM-11 NitrOS-9 Level $LEVEL $CPU image build complete."
case "$MEDIA" in
    2d) echo "  fm11-l${LEVEL}-${CPU}-2d.{rbf,d88}" ;;
    2hd) echo "  fm11-l${LEVEL}-${CPU}-2hd.{rbf,d88}" ;;
    all) echo "  fm11-l${LEVEL}-${CPU}-2d.{rbf,d88}"; echo "  fm11-l${LEVEL}-${CPU}-2hd.{rbf,d88}" ;;
esac
