#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
FM="$ROOT/level2/fm11"

usage() {
    echo "usage: $0 6809|6309|all" >&2
    exit 2
}

need_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "$1 is required" >&2
        exit 1
    }
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

    # Common sources that already support both OS levels.
    build "$ROOT/level1/modules/ioman.asm"       ioman
    build "$ROOT/level1/modules/rbsuper.asm"     rbsuper -Dwildbits=1 -DDrvCount=1
    build "$ROOT/level1/modules/scf.asm"         scf
    build "$ROOT/level2/modules/clock.asm"         clock
    build "$ROOT/level1/modules/clock2_soft.asm" clock2_soft
    build "$ROOT/level1/modules/sysgo.asm"       sysgo -DDD=1

    # Level 2 RBF manager.
    build "$ROOT/level2/modules/rbf.asm"         rbf

    # Initial command interpreter.  Keep a resident copy in OS9Boot and
    # also install it in /DD/CMDS.
    build "$ROOT/level1/cmds/shell_21.asm"       shell

    # External commands used for bring-up and scheduler/IRQ testing.
    build "$ROOT/level1/cmds/dir.asm"            dir
    build "$ROOT/level1/cmds/sleep.asm"          sleep
    build "$ROOT/level2/cmds/procs.asm"          procs
    build "$ROOT/level1/cmds/date.asm"           date

    # Basic disk/file utilities.  These are kept out of OS9Boot and installed
    # only in /DD/CMDS so the boot module set remains small.
    build "$ROOT/level1/cmds/copy.asm"           copy
    build "$ROOT/level1/cmds/dsave.asm"          dsave
    build "$ROOT/level1/cmds/cmp.asm"            cmp
    build "$ROOT/level1/cmds/makdir.asm"         makdir
    build "$ROOT/level1/cmds/del.asm"            del
    build "$ROOT/level1/cmds/attr.asm"           attr
    build "$ROOT/level1/cmds/list.asm"           list
    build "$ROOT/level1/cmds/free.asm"           free

    BOOTLIST="$FM/bootlists/bootlist.2d"
    OS9BOOT="$OUT/OS9Boot-2d"
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

    RBF="$ROOT/fm11-l2-system-$CPU-2d.rbf"
    D88="$ROOT/fm11-l2-system-$CPU-2d.d88"
    RBF_SECTORS=$((39 * 2 * 16))
    rm -f "$RBF" "$D88"

    os9 format -e -l"$RBF_SECTORS" -bs256 -q "$RBF" -n"FM11L2"
    os9 copy -o=0 "$OS9BOOT" "$RBF,OS9Boot"
    os9 makdir "$RBF,CMDS"
    os9 copy -o=0 "$OUT/shell" "$RBF,CMDS/Shell"
    os9 attr "$RBF,CMDS/Shell" -e -pe >/dev/null
    os9 copy -o=0 "$OUT/dir" "$RBF,CMDS/Dir"
    os9 attr "$RBF,CMDS/Dir" -e -pe >/dev/null
    os9 copy -o=0 "$OUT/sleep" "$RBF,CMDS/Sleep"
    os9 attr "$RBF,CMDS/Sleep" -e -pe >/dev/null
    os9 copy -o=0 "$OUT/procs" "$RBF,CMDS/Procs"
    os9 attr "$RBF,CMDS/Procs" -e -pe >/dev/null
    os9 copy -o=0 "$OUT/date" "$RBF,CMDS/Date"
    os9 attr "$RBF,CMDS/Date" -e -pe >/dev/null

    for cmd in copy dsave cmp makdir del attr list free; do
        case "$cmd" in
            copy)   diskname=Copy ;;
            dsave)  diskname=DSave ;;
            cmp)    diskname=Cmp ;;
            makdir) diskname=MakDir ;;
            del)    diskname=Del ;;
            attr)   diskname=Attr ;;
            list)   diskname=List ;;
            free)   diskname=Free ;;
        esac
        os9 copy -o=0 "$OUT/$cmd" "$RBF,CMDS/$diskname"
        os9 attr "$RBF,CMDS/$diskname" -e -pe >/dev/null
    done

    # Boot_common follows DD.BT to the /OS9Boot file descriptor.
    python3 "$ROOT/patch-boot-descriptor.py" "$RBF"

    # Keep the editable RBF image, but apply the FM-11 geometry only to
    # the private copy consumed by the D88 writer.
    RBFTMP=$(mktemp "${TMPDIR:-/tmp}/fm11-l2-rbf.XXXXXX")
    trap 'rm -f "$RBFTMP"' EXIT HUP INT TERM
    cp "$RBF" "$RBFTMP"
    python3 "$ROOT/patch-rbf-floppy.py" "$RBFTMP" 2d

    python3 "$FM/make-d88-l2.py" \
        "$RBFTMP" \
        "$OUT/ipl-2d.bin" \
        "$OUT/kerneltrack-2d" \
        "$D88" \
        --label "FM11 L2 $CPU"

    rm -f "$RBFTMP"
    trap - EXIT HUP INT TERM

    RBFSIZE=$(wc -c < "$RBF" | tr -d ' ')
    D88SIZE=$(wc -c < "$D88" | tr -d ' ')

    echo "FM-11 Level 2 $CPU 2D image:"
    echo "  OS9Boot: $OS9SIZE bytes"
    echo "  RBF:     $RBF ($RBFSIZE bytes)"
    echo "  D88:     $D88 ($D88SIZE bytes)"
}

need_tool lwasm
need_tool os9
need_tool python3

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
