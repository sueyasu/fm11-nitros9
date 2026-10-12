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
    OUT="$FM/build-core-$CPU"
    [ -d "$OUT" ] || { echo "Missing $OUT; run l2-build-core.sh first" >&2; exit 1; }

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

    build() {
        src=$1
        dst=$2
        shift 2
        # shellcheck disable=SC2086
        $ASBASE "$@" --format=os9 --output="$OUT/$dst" "$src"
    }

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

    # Runtime system modules and commands.  Keep all assembly here so the
    # floppy-image stage only lays out already-built binaries.
    build "$ROOT/level1/modules/ioman.asm"       ioman
    build "$ROOT/level1/modules/rbsuper.asm"     rbsuper -Dwildbits=1 -DDrvCount=5
    build "$ROOT/level1/modules/scf.asm"         scf
    build "$ROOT/level2/modules/clock.asm"       clock
    build "$ROOT/level1/modules/clock2_soft.asm" clock2_soft
    build "$ROOT/level1/modules/sysgo.asm"       sysgo -DDD=1
    build "$ROOT/level2/modules/rbf.asm"          rbf
    build "$ROOT/level1/cmds/shell_21.asm"       shell
    build "$ROOT/level1/cmds/dir.asm"            dir
    build "$ROOT/level1/cmds/sleep.asm"          sleep
    build "$ROOT/level2/cmds/procs.asm"          procs
    build "$ROOT/level1/cmds/date.asm"           date
    build "$ROOT/level1/cmds/xmode.asm"          tmode -DTMODE=1
    build "$ROOT/level1/cmds/copy.asm"           copy
    build "$ROOT/level1/cmds/dsave.asm"          dsave
    build "$ROOT/level1/cmds/cmp.asm"            cmp
    build "$ROOT/level1/cmds/load.asm"           load
    build "$ROOT/level1/cmds/unlink.asm"         unlink
    build "$ROOT/level1/cmds/makdir.asm"         makdir
    build "$ROOT/level1/cmds/del.asm"            del
    build "$ROOT/level1/cmds/attr.asm"           attr
    build "$ROOT/level1/cmds/list.asm"           list
    build "$ROOT/level1/cmds/free.asm"           free

    for cmd in \
        build deiniz deldir devs dmode dump echo ident iniz link \
        mdir merge prompt rename save setime tee touch tsmon verify \
        dirsort binex exbin disasm edit dcheck backup
    do
        build "$ROOT/level1/cmds/$cmd.asm" "$cmd"
    done

    build "$ROOT/level1/fm11/cmds/more.asm"        more
    build "$ROOT/level1/fm11/cmds/minted.asm"      minted
    build "$ROOT/level1/fm11/cmds/ded.asm"         ded

    build "$ROOT/level2/cmds/dmem.asm"             dmem
    build "$ROOT/level2/cmds/mdir.asm"             mdir
    build "$ROOT/level2/cmds/mfree.asm"            mfree
    build "$ROOT/level2/cmds/mmap.asm"             mmap
    build "$ROOT/level2/cmds/pmap.asm"             pmap
    build "$ROOT/level2/cmds/proc.asm"             proc

    build "$ROOT/level1/fm11/cmds/format.asm"       format
    build "$ROOT/level1/fm11/cmds/cobbler.asm"      cobbler
    build "$ROOT/level1/fm11/cmds/os9gen.asm"       os9gen
    build "$ROOT/level1/cmds/pd.asm"               pwd -DPWD=1
    build "$ROOT/level1/cmds/pd.asm"               pxd -DPXD=1

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
