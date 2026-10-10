#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$DIR/../../.." && pwd)
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

    "$DIR/l2-build-core.sh" "$CPU"
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

    bin_to_fcb() {
        od -An -v -tx1 "$1" | awk '{
            printf "                    fcb       "
            for (i = 1; i <= NF; i++) {
                printf "$%s", toupper($i)
                if (i != NF)
                    printf ","
            }
            printf "\n"
        }' > "$2"
    }

    for src in llfm11 llfm11hd h0_m2230b_fm11 h0_m2231b_fm11 h0_m2232b_fm11 h0_m2233b_fm11 h0_m2234b_fm11 h0_m2235b_fm11 h0_m2241b_fm11 h0_m2242b_fm11 h0_m2243b_fm11 dd_m2230b_fm11 dd_m2231b_fm11 dd_m2232b_fm11 dd_m2233b_fm11 dd_m2234b_fm11 dd_m2235b_fm11 dd_m2241b_fm11 dd_m2242b_fm11 dd_m2243b_fm11 d0_fm11 d1_fm11 d2_fm11 d3_fm11 d0_2hd_fm11 d1_2hd_fm11 d2_2hd_fm11 d3_2hd_fm11 dd_fm11 dd_2hd_fm11 md0_fm11 md1_fm11 nd0_fm11 nd1_fm11 fm11console term_fm11 fm11serial t1_fm11 init_fm11; do
        # shellcheck disable=SC2086
        $ASBASE --format=os9 --output="$OUT/$src" "$FM/modules/$src.asm"
    done

    # Cobbler embeds the Level 2 target descriptors exactly as the Level 1
    # build does.  At run time it substitutes only these modules while copying
    # the resident OS9Boot image module-by-module.
    for spec in \
        d0-2d:d0_fm11 d1-2d:d1_fm11 d2-2d:d2_fm11 d3-2d:d3_fm11 dd-2d:dd_fm11 \
        d0-2hd:d0_2hd_fm11 d1-2hd:d1_2hd_fm11 d2-2hd:d2_2hd_fm11 d3-2hd:d3_2hd_fm11 dd-2hd:dd_2hd_fm11 \
        h0-m2231b:h0_m2231b_fm11 dd-m2231b:dd_m2231b_fm11 \
        h0-m2230b:h0_m2230b_fm11 dd-m2230b:dd_m2230b_fm11 \
        h0-m2232b:h0_m2232b_fm11 dd-m2232b:dd_m2232b_fm11 \
        h0-m2233b:h0_m2233b_fm11 dd-m2233b:dd_m2233b_fm11 \
        h0-m2234b:h0_m2234b_fm11 dd-m2234b:dd_m2234b_fm11 \
        h0-m2235b:h0_m2235b_fm11 dd-m2235b:dd_m2235b_fm11 \
        h0-m2241b:h0_m2241b_fm11 dd-m2241b:dd_m2241b_fm11 \
        h0-m2242b:h0_m2242b_fm11 dd-m2242b:dd_m2242b_fm11 \
        h0-m2243b:h0_m2243b_fm11 dd-m2243b:dd_m2243b_fm11
    do
        tag=${spec%%:*}
        bin=${spec#*:}
        bin_to_fcb "$OUT/$bin" "$OUT/cobbler-$tag.asm"
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
    for f in llfm11 llfm11hd h0_m2230b_fm11 h0_m2231b_fm11 h0_m2232b_fm11 h0_m2233b_fm11 h0_m2234b_fm11 h0_m2235b_fm11 h0_m2241b_fm11 h0_m2242b_fm11 h0_m2243b_fm11 dd_m2230b_fm11 dd_m2231b_fm11 dd_m2232b_fm11 dd_m2233b_fm11 dd_m2234b_fm11 dd_m2235b_fm11 dd_m2241b_fm11 dd_m2242b_fm11 dd_m2243b_fm11 d0_fm11 d1_fm11 d2_fm11 d3_fm11 d0_2hd_fm11 d1_2hd_fm11 d2_2hd_fm11 d3_2hd_fm11 dd_fm11 dd_2hd_fm11 md0_fm11 md1_fm11 nd0_fm11 nd1_fm11 fm11console term_fm11 fm11serial t1_fm11 init_fm11 pipeman piper pipe; do

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
