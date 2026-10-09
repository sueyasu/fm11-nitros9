#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
FM="$ROOT/level2/fm11"

usage() {
    echo "usage: $0 6809|6309|all [m2230b|m2231b|m2232b|m2233b|m2234b|m2235b|m2241b|m2242b|m2243b|all]" >&2
    exit 2
}

geometry() {
    case "$1" in
        m2230b) echo "315 2" ;;
        m2231b) echo "157 4" ;;
        m2232b) echo "157 6" ;;
        m2233b) echo "315 4" ;;
        m2234b) echo "315 6" ;;
        m2235b) echo "315 8" ;;
        m2241b) echo "747 4" ;;
        m2242b) echo "747 7" ;;
        m2243b) echo "747 11" ;;
        *) return 1 ;;
    esac
}

need_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "$1 is required" >&2
        exit 1
    }
}

build_cpu() {
    CPU=$1
    MODELSEL=$2

    case "$CPU" in
        6809) LWCPU=--6809; H6309=0 ;;
        6309) LWCPU=--6309; H6309=1 ;;
        *) usage ;;
    esac

    "$FM/build-runtime.sh" "$CPU"
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

    build() {
        src=$1
        dst=$2
        shift 2
        # shellcheck disable=SC2086
        $ASBASE "$@" --format=os9 --output="$OUT/$dst" "$src"
    }

    build "$ROOT/level1/modules/ioman.asm"       ioman
    build "$ROOT/level1/modules/rbsuper.asm"     rbsuper -Dwildbits=1 -DDrvCount=5
    build "$ROOT/level1/modules/scf.asm"         scf
    build "$ROOT/level2/modules/clock.asm"       clock
    build "$ROOT/level1/modules/clock2_soft.asm" clock2_soft
    build "$ROOT/level1/modules/sysgo.asm"       sysgo -DDD=1
    build "$ROOT/level2/modules/rbf.asm"         rbf
    build "$ROOT/level1/cmds/shell_21.asm"       shell
    build "$ROOT/level1/cmds/dir.asm"            dir
    build "$ROOT/level1/cmds/free.asm"           free

    # Match the normal command set installed in the floppy images.
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

    # Additional standard commands used by the Level 1 FM-11 distribution.
    for cmd in \
        build deiniz deldir devs dmode dump echo ident iniz link \
        mdir merge prompt rename save setime tee touch tsmon verify \
        dirsort binex exbin disasm edit dcheck backup
    do
        build "$ROOT/level1/cmds/$cmd.asm" "$cmd"
    done

    # More uses the FM-11 ANSI/VT100 variant already proven on Level 1.
    build "$ROOT/level1/fm11/cmds/more.asm"        more

    # FM-11 screen editors already ported and proven on Level 1.
    build "$ROOT/level1/fm11/cmds/minted.asm"      minted
    build "$ROOT/level1/fm11/cmds/ded.asm"         ded

    # Level 2-specific, machine-independent diagnostics and utilities.
    # These use public Level 2 system calls rather than FM-11 hardware directly.
    build "$ROOT/level2/cmds/dmem.asm"             dmem
    build "$ROOT/level2/cmds/mdir.asm"             mdir
    build "$ROOT/level2/cmds/mfree.asm"            mfree
    build "$ROOT/level2/cmds/mmap.asm"             mmap
    build "$ROOT/level2/cmds/pmap.asm"             pmap
    build "$ROOT/level2/cmds/proc.asm"             proc

    # pd.asm is the common source for Pwd and Pxd.
    build "$ROOT/level1/cmds/pd.asm"               pwd -DPWD=1
    build "$ROOT/level1/cmds/pd.asm"               pxd -DPXD=1

    case "$MODELSEL" in
        all)
            for m in m2230b m2231b m2232b m2233b m2234b m2235b m2241b m2242b m2243b; do
                build_model "$CPU" "$m" "$OUT"
            done
            ;;
        *)
            geometry "$MODELSEL" >/dev/null || usage
            build_model "$CPU" "$MODELSEL" "$OUT"
            ;;
    esac
}

build_model() {
    CPU=$1
    MODEL=$2
    OUT=$3

    set -- $(geometry "$MODEL")
    CYL=$1
    HEADS=$2
    TOTAL=$((CYL * HEADS * 32))
    RESERVE=23
    RBF_SECTORS=$((TOTAL - RESERVE))

    OS9BOOT="$OUT/OS9Boot-hd-$MODEL"
    : > "$OS9BOOT"

    for module in \
        krnp2 fm11trampmod ioman init_fm11 rbf rbsuper \
        llfm11 llfm11hd "dd_${MODEL}_fm11" "h0_${MODEL}_fm11" \
        d0_fm11 d1_fm11 d2_fm11 d3_fm11 \
        md0_fm11 md1_fm11 nd0_fm11 nd1_fm11 \
        scf fm11console term_fm11 \
        fm11serial t1_fm11 clock clock2_soft sysgo \
        pipeman piper pipe shell
    do
        if [ ! -f "$OUT/$module" ]; then
            echo "Missing boot module: $OUT/$module" >&2
            exit 1
        fi
        cat "$OUT/$module" >> "$OS9BOOT"
    done

    OS9SIZE=$(wc -c < "$OS9BOOT" | tr -d ' ')
    if [ "$OS9SIZE" -eq 0 ] || [ "$OS9SIZE" -gt 65535 ]; then
        echo "Invalid OS9Boot size: $OS9SIZE" >&2
        exit 1
    fi

    RBF="$ROOT/fm11-l2-system-$CPU-$MODEL.rbf"
    HDD="$ROOT/fm11-l2-system-$CPU-$MODEL.hdd"
    rm -f "$RBF" "$HDD"

    os9 format -e -l"$RBF_SECTORS" -bs256 -q "$RBF" -n"FM11L2HD"
    os9 copy -o=0 "$OS9BOOT" "$RBF,OS9Boot"
    os9 makdir "$RBF,CMDS"
    for item in \
        shell:Shell dir:Dir sleep:Sleep procs:Procs date:Date tmode:TMode \
        copy:Copy dsave:DSave cmp:Cmp load:Load unlink:Unlink \
        makdir:MakDir del:Del attr:Attr list:List free:Free \
        build:Build deiniz:DeIniz deldir:DelDir devs:Devs dmode:DMode \
        dump:Dump echo:Echo ident:Ident iniz:Iniz link:Link mdir:MDir \
        merge:Merge prompt:Prompt rename:Rename save:Save setime:Setime \
        tee:Tee touch:Touch tsmon:TSMon verify:Verify \
        dirsort:DirSort binex:Binex exbin:Exbin disasm:Disasm edit:Edit \
        more:More dcheck:DCheck backup:Backup pwd:Pwd pxd:Pxd \
        minted:MinTED ded:dEd \
        dmem:DMem mfree:MFree mmap:MMap pmap:PMap proc:Proc
    do
        src=${item%%:*}
        dst=${item#*:}
        os9 copy -o=0 "$OUT/$src" "$RBF,CMDS/$dst"
        os9 attr "$RBF,CMDS/$dst" -e -pe >/dev/null
    done

    python3 "$ROOT/patch-boot-descriptor.py" "$RBF"

    IPLTMP=$(mktemp "${TMPDIR:-/tmp}/fm11-l2-hdipl.XXXXXX")
    trap 'rm -f "$IPLTMP"' EXIT HUP INT TERM
    cp "$OUT/ipl-hd.bin" "$IPLTMP"
    truncate -s 512 "$IPLTMP"

    cat "$IPLTMP" "$OUT/kerneltrack-hd" "$RBF" > "$HDD"
    rm -f "$IPLTMP"
    trap - EXIT HUP INT TERM

    EXPECT=$((TOTAL * 256))
    ACTUAL=$(wc -c < "$HDD" | tr -d ' ')
    if [ "$ACTUAL" -ne "$EXPECT" ]; then
        echo "HDD image size error for $MODEL: $ACTUAL (expected $EXPECT)" >&2
        exit 1
    fi

    echo "FM-11 Level 2 $CPU $MODEL HDD image:"
    echo "  geometry: $CYL cylinders x $HEADS heads x 32 sectors"
    echo "  reserved: sectors 0-22 (IPL + 21-sector kernel track)"
    echo "  RBF:      $RBF ($RBF_SECTORS sectors)"
    echo "  OS9Boot:  $OS9SIZE bytes"
    echo "  HDD:      $HDD ($ACTUAL bytes)"
}

need_tool lwasm
need_tool os9
need_tool python3

CPUSEL=${1:-}
MODELSEL=${2:-m2233b}

case "$CPUSEL" in
    6809|6309) build_cpu "$CPUSEL" "$MODELSEL" ;;
    all)
        build_cpu 6809 "$MODELSEL"
        build_cpu 6309 "$MODELSEL"
        ;;
    *) usage ;;
esac
