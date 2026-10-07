#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
FM="$ROOT/level2/fm11"

usage() {
    echo "usage: $0 6809|6309|all" >&2
    exit 2
}

pad_file() {
    src=$1
    dst=$2
    size=$3
    actual=$(wc -c < "$src" | tr -d ' ')
    if [ "$actual" -gt "$size" ]; then
        echo "$src is too large: $actual bytes (slot $size)" >&2
        exit 1
    fi
    cp "$src" "$dst"
    truncate -s "$size" "$dst"
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
    rm -rf "$OUT"
    mkdir -p "$OUT"

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

    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/rel" "$FM/modules/rel.asm"

    # shellcheck disable=SC2086
    $ASBASE --format=raw --output="$OUT/ipl-2d.bin" "$FM/ipl/ipl_fdd.asm"

    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/boot" "$FM/modules/boot_fdd.asm"

    # Common Krn/KrnP2 include the FM-11 MMU primitive layer when fm11=1.
    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/krn" \
        "$ROOT/level2/modules/kernel/krn.asm"

    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/krnp2" \
        "$ROOT/level2/modules/kernel/krnp2.asm"

    # shellcheck disable=SC2086
    $ASBASE --format=raw --output="$OUT/fm11tramp.bin" \
        "$FM/fm11tramp.asm"

    # shellcheck disable=SC2086
    $ASBASE --format=os9 --output="$OUT/fm11trampmod" \
        "$FM/modules/fm11trampmod.asm"

    RELSIZE=$(wc -c < "$OUT/rel" | tr -d ' ')
    IPLSIZE=$(wc -c < "$OUT/ipl-2d.bin" | tr -d ' ')
    BOOTSIZE=$(wc -c < "$OUT/boot" | tr -d ' ')
    KRNSIZE=$(wc -c < "$OUT/krn" | tr -d ' ')
    KRNP2SIZE=$(wc -c < "$OUT/krnp2" | tr -d ' ')
    TRAMPSIZE=$(wc -c < "$OUT/fm11tramp.bin" | tr -d ' ')

    REL_SLOT=$((0x130))
    BOOT_SLOT=$((0x150))
    KRN_SLOT=$((0x1200))
    TRACK_PAYLOAD=$((0x1480))
    TRACK_SIZE=$((0x1500))
    TRAMP_SIZE=$((0xfff0-0xfe00))

    if [ "$IPLSIZE" -gt 512 ]; then
        echo "IPL too large: $IPLSIZE bytes" >&2
        exit 1
    fi
    if [ "$RELSIZE" -ne "$REL_SLOT" ]; then
        echo "REL size error: $RELSIZE (expected $REL_SLOT)" >&2
        exit 1
    fi
    if [ "$TRAMPSIZE" -ne "$TRAMP_SIZE" ]; then
        echo "trampoline size error: $TRAMPSIZE (expected $TRAMP_SIZE)" >&2
        exit 1
    fi

    pad_file "$OUT/boot" "$OUT/boot.slot" "$BOOT_SLOT"
    pad_file "$OUT/krn" "$OUT/krn.slot" "$KRN_SLOT"

    cat "$OUT/rel" "$OUT/boot.slot" "$OUT/krn.slot" > "$OUT/kerneltrack-2d"
    PAYLOADSIZE=$(wc -c < "$OUT/kerneltrack-2d" | tr -d ' ')
    if [ "$PAYLOADSIZE" -ne "$TRACK_PAYLOAD" ]; then
        echo "kernel payload size error: $PAYLOADSIZE (expected $TRACK_PAYLOAD)" >&2
        exit 1
    fi
    truncate -s "$TRACK_SIZE" "$OUT/kerneltrack-2d"
    TRACKSIZE=$(wc -c < "$OUT/kerneltrack-2d" | tr -d ' ')
    if [ "$TRACKSIZE" -ne "$TRACK_SIZE" ]; then
        echo "kernel track size error: $TRACKSIZE (expected $TRACK_SIZE)" >&2
        exit 1
    fi

    echo "FM-11 Level 2 $CPU 8K-pair core:"
    echo "  IPL:          $IPLSIZE bytes"
    echo "  REL:          $RELSIZE bytes"
    echo "  Boot:         $BOOTSIZE bytes (slot $BOOT_SLOT)"
    echo "  Krn:          $KRNSIZE bytes (slot $KRN_SLOT)"
    echo "  KrnP2:        $KRNP2SIZE bytes"
    echo "  trampoline:   $TRAMPSIZE bytes"
    echo "  kernel track: $TRACKSIZE bytes"
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
