#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$DIR/../../.." && pwd)
FM="$ROOT/level2/fm11"

usage() {
    echo "usage: $0 6809|6309 2d|2hd|all" >&2
    exit 2
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
        more:More dcheck:DCheck backup:Backup pwd:Pwd pxd:Pxd \
        minted:MinTED ded:dEd \
        dmem:DMem mfree:MFree mmap:MMap pmap:PMap proc:Proc \
        format:Format cobbler:Cobbler os9gen:OS9Gen
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

    # OS9Gen reads its boot modules as files.  Install the union of the 2D
    # and 2HD bootlists, then generate CR-terminated target lists using /DD
    # so the source remains the currently booted system disk.
    for module in $(awk '!/^#/ && NF && !seen[$0]++ { print $0 }' \
        "$FM/bootlists/bootlist.2d" "$FM/bootlists/bootlist.2hd")
    do
        os9 copy -o=0 "$OUT/$module" "$RBF,SYS/MODULES/$module"
    done
    for media in 2d 2hd; do
        bltmp=$(mktemp "${TMPDIR:-/tmp}/fm11-l2-bootlist.XXXXXX")
        awk '!/^#/ && NF { printf "/DD/SYS/MODULES/%s\r", $0 }' \
            "$FM/bootlists/bootlist.$media" > "$bltmp"
        os9 copy -o=0 "$bltmp" "$RBF,SYS/bootlist.$media"
        rm -f "$bltmp"
    done

    for module in llfm11hd \
        h0_m2230b_fm11 h0_m2231b_fm11 h0_m2232b_fm11 \
        h0_m2233b_fm11 h0_m2234b_fm11 h0_m2235b_fm11 \
        h0_m2241b_fm11 h0_m2242b_fm11 h0_m2243b_fm11
    do
        os9 copy -o=0 "$OUT/$module" "$RBF,SYS/MODULES/$module"
    done

    # Cobbler reads target-specific IPL and kernel-track images from /DD/SYS.
    # Install all target profiles on every system floppy so a 2D booted
    # system may cobble 2HD/HDD media and vice versa.
    os9 makdir "$RBF,SYS/IPL"
    os9 makdir "$RBF,SYS/BOOT"
    os9 copy -o=0 "$OUT/IPL.2D"     "$RBF,SYS/IPL/IPL.2D"
    os9 copy -o=0 "$OUT/IPL.2HD"    "$RBF,SYS/IPL/IPL.2HD"
    os9 copy -o=0 "$OUT/IPL.HD"     "$RBF,SYS/IPL/IPL.HD"
    os9 copy -o=0 "$OUT/Bootp1.2D"  "$RBF,SYS/BOOT/Bootp1.2D"
    os9 copy -o=0 "$OUT/Bootp1.2HD" "$RBF,SYS/BOOT/Bootp1.2HD"
    os9 copy -o=0 "$OUT/Bootp1.HD"  "$RBF,SYS/BOOT/Bootp1.HD"

    python3 "$DIR/patch-boot-descriptor.py" "$RBF"

    RBFTMP=$(mktemp "${TMPDIR:-/tmp}/fm11-l2-rbf.XXXXXX")
    cp "$RBF" "$RBFTMP"
    python3 "$DIR/patch-rbf-floppy.py" "$RBFTMP" "$MEDIA"

    python3 "$DIR/l2-make-d88.py" \
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

CPUSEL=${1:-}
MEDIASEL_TOP=${2:-all}
case "$CPUSEL" in
    6809|6309) ;;
    *) usage ;;
esac
OUT="$FM/build-core-$CPUSEL"
[ -d "$OUT" ] || { echo "Missing $OUT; run l2-build-core.sh and l2-build-runtime.sh first" >&2; exit 1; }

case "$MEDIASEL_TOP" in
    2d|2hd) build_media "$CPUSEL" "$MEDIASEL_TOP" "$OUT" ;;
    all) build_media "$CPUSEL" 2d "$OUT"; build_media "$CPUSEL" 2hd "$OUT" ;;
    *) usage ;;
esac
