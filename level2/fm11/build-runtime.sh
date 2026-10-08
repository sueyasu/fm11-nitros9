#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
FM="$ROOT/level2/fm11"

usage() {
    echo "usage: $0 6809|6309|all" >&2
    exit 2
}

build_one() {
    CPU=$1
    case "$CPU" in
        6809)
            LWCPU=--6809
            H6309=0
            ;;
        6309)
            LWCPU=--6309
            H6309=1
            ;;
        *)
            usage
            ;;
    esac

    "$FM/build-core.sh" "$CPU"
    OUT="$FM/build-core-$CPU"

    NOS9VER=${NOS9VER:-0}
    NOS9MAJ=${NOS9MAJ:-0}
    NOS9MIN=${NOS9MIN:-0}

    ASBASE="lwasm --no-warn=ifp1 $LWCPU \
--pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax \
--includedir=$OUT \
--includedir=$FM \
--includedir=$FM/kernel \
--includedir=$FM/modules \
--includedir=$ROOT/defs \
--includedir=$ROOT/level2/modules \
--includedir=$ROOT/level2/modules/kernel \
--includedir=$ROOT/level1/modules \
--includedir=$ROOT/level1/modules/kernel \
-Dfm11=1 -DH6309=$H6309 \
-DNOS9VER=$NOS9VER -DNOS9MAJ=$NOS9MAJ -DNOS9MIN=$NOS9MIN"

    for src in llfm11 d0_fm11 d1_fm11 d2_fm11 d3_fm11 d0_2hd_fm11 d1_2hd_fm11 d2_2hd_fm11 d3_2hd_fm11 dd_fm11 dd_2hd_fm11 md0_fm11 md1_fm11 nd0_fm11 nd1_fm11 fm11serial t1_fm11 init_fm11; do
        # shellcheck disable=SC2086
        $ASBASE --format=os9 --output="$OUT/$src" "$FM/modules/$src.asm"
    done

    # Anonymous PipeMan used by the classic Shell pipeline operator (!).
    # This source contains Level 2 conditional code and is the appropriate
    # implementation for the /pipe device used by shell_21.asm.
    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/pipeman" "$ROOT/level1/modules/pipeman.asm"

    # Pipe device driver and /pipe device descriptor.
    # These generic modules are shared with Level 1 and are required by PipeMan.
    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/piper" "$ROOT/level1/modules/piper.asm"
    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/pipe" "$ROOT/level1/modules/pipe.asm"

    echo "FM-11 Level 2 $CPU bring-up modules:"
    for f in llfm11 d0_fm11 d1_fm11 d2_fm11 d3_fm11 d0_2hd_fm11 d1_2hd_fm11 d2_2hd_fm11 d3_2hd_fm11 dd_fm11 dd_2hd_fm11 md0_fm11 md1_fm11 nd0_fm11 nd1_fm11 fm11serial t1_fm11 init_fm11 pipeman piper pipe; do
        size=$(wc -c < "$OUT/$f" | tr -d ' ')
        printf '  %-12s %s bytes\n' "$f:" "$size"
    done
}

case "${1:-}" in
    6809|6309)
        build_one "$1"
        ;;
    all)
        build_one 6809
        build_one 6309
        ;;
    *)
        usage
        ;;
esac
