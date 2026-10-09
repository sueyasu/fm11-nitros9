#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
FM="$ROOT/level2/fm11"

usage() {
    echo "usage: $0 6809|6309|all 2d|2hd|all" >&2
    exit 2
}

need_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "$1 is required" >&2
        exit 1
    }
}

build_cpu() {
    CPU=$1
    MEDIASEL=$2

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

    # Additional standard commands used by the Level 1 FM-11 distribution.
    # These are generic commands that do not require FM-11-specific low-level
    # device services and can be shared with Level 2 as-is.
    for cmd in \
        build deiniz deldir devs dmode dump echo ident iniz link \
        mdir merge prompt rename save setime tee touch tsmon verify \
        dirsort binex exbin disasm edit dcheck backup
    do
        build "$ROOT/level1/cmds/$cmd.asm" "$cmd"
    done

    # More uses the FM-11 ANSI/VT100 variant already proven on Level 1.
    build "$ROOT/level1/fm11/cmds/more.asm"        more

    # pd.asm is the common source for Pwd and Pxd.
    build "$ROOT/level1/cmds/pd.asm"               pwd -DPWD=1
    build "$ROOT/level1/cmds/pd.asm"               pxd -DPXD=1

    case "$MEDIASEL" in
        2d|2hd) build_media "$CPU" "$MEDIASEL" "$OUT" ;;
        all)
            build_media "$CPU" 2d "$OUT"
            build_media "$CPU" 2hd "$OUT"
            ;;
        *) usage ;;
    esac
}

build_media() {
    CPU=$1
    MEDIA=$2
    OUT=$3

    case "$MEDIA" in
        2d)
            BOOTLIST="$FM/bootlists/bootlist.2d"
            RBF_SECTORS=$((39 * 2 * 16))
            IPL="$OUT/ipl-2d.bin"
            KERNELTRACK="$OUT/kerneltrack-2d"
            ;;
        2hd)
            BOOTLIST="$FM/bootlists/bootlist.2hd"
            RBF_SECTORS=$((76 * 2 * 26))
            IPL="$OUT/ipl-2hd.bin"
            KERNELTRACK="$OUT/kerneltrack-2hd"
            ;;
        *) usage ;;
    esac

    OS9BOOT="$OUT/OS9Boot-$MEDIA"
    : > "$OS9BOOT"
    while IFS= read -r module; do
        case "$module" in
            ''|'#'*) continue ;;
        esac
        if [ ! -f "$OUT/$module" ]; then
            echo "Missing boot module: $OUT/$module" >&2
            exit 1
        fi
        cat "$OUT/$module" >> "$OS9BOOT"
    done < "$BOOTLIST"

    OS9SIZE=$(wc -c < "$OS9BOOT" | tr -d ' ')
    if [ "$OS9SIZE" -eq 0 ] || [ "$OS9SIZE" -gt 65535 ]; then
        echo "Invalid OS9Boot size: $OS9SIZE" >&2
        exit 1
    fi

    RBF="$ROOT/fm11-l2-system-$CPU-$MEDIA.rbf"
    D88="$ROOT/fm11-l2-system-$CPU-$MEDIA.d88"
    rm -f "$RBF" "$D88"

    os9 format -e -l"$RBF_SECTORS" -bs256 -q "$RBF" -n"FM11L2"
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
        more:More dcheck:DCheck backup:Backup pwd:Pwd pxd:Pxd
    do
        src=${item%%:*}
        dst=${item#*:}
        os9 copy -o=0 "$OUT/$src" "$RBF,CMDS/$dst"
        os9 attr "$RBF,CMDS/$dst" -e -pe >/dev/null
    done

    # Keep all supported H0 profiles in /SYS/MODULES.  M2233B alone is
    # resident in the default OS9Boot; the others are alternate source modules.
    os9 makdir "$RBF,SYS"
    os9 makdir "$RBF,SYS/MODULES"
    for module in llfm11hd \
        h0_m2230b_fm11 h0_m2231b_fm11 h0_m2232b_fm11 \
        h0_m2233b_fm11 h0_m2234b_fm11 h0_m2235b_fm11 \
        h0_m2241b_fm11 h0_m2242b_fm11 h0_m2243b_fm11
    do
        os9 copy -o=0 "$OUT/$module" "$RBF,SYS/MODULES/$module"
    done

    python3 "$ROOT/patch-boot-descriptor.py" "$RBF"

    RBFTMP=$(mktemp "${TMPDIR:-/tmp}/fm11-l2-rbf.XXXXXX")
    cp "$RBF" "$RBFTMP"
    python3 "$ROOT/patch-rbf-floppy.py" "$RBFTMP" "$MEDIA"

    python3 "$FM/make-d88-l2-floppy.py" \
        "$RBFTMP" "$IPL" "$KERNELTRACK" "$D88" \
        --media "$MEDIA" --label "FM11 L2 $CPU $MEDIA"

    rm -f "$RBFTMP"

    RBFSIZE=$(wc -c < "$RBF" | tr -d ' ')
    D88SIZE=$(wc -c < "$D88" | tr -d ' ')
    echo "FM-11 Level 2 $CPU ${MEDIA} image:"
    echo "  OS9Boot: $OS9SIZE bytes"
    echo "  RBF:     $RBF ($RBFSIZE bytes)"
    echo "  D88:     $D88 ($D88SIZE bytes)"
}

need_tool lwasm
need_tool os9
need_tool python3

CPUSEL=${1:-}
MEDIASEL_TOP=${2:-}
case "$CPUSEL" in
    6809|6309) build_cpu "$CPUSEL" "$MEDIASEL_TOP" ;;
    all)
        build_cpu 6809 "$MEDIASEL_TOP"
        build_cpu 6309 "$MEDIASEL_TOP"
        ;;
    *) usage ;;
esac
