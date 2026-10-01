#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FM="$ROOT/level1/fm11"

CPU=${1:-}
case "$CPU" in
    6809)
        LWCPU=--6809
        H6309=0
        CPU_LABEL=6809
        ;;
    6309)
        LWCPU=--6309
        H6309=1
        CPU_LABEL=HD63C09
        ;;
    *)
        echo "usage: $0 6809|6309" >&2
        exit 2
        ;;
esac

OUT="$FM/build-minimal-$CPU"
rm -rf "$OUT"
mkdir -p "$OUT"

NOS9VER=${NOS9VER:-0}
NOS9MAJ=${NOS9MAJ:-0}
NOS9MIN=${NOS9MIN:-0}

AS_COMMON="lwasm --no-warn=ifp1 $LWCPU --format=os9 --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax --includedir=$OUT --includedir=$ROOT/defs --includedir=$FM --includedir=$ROOT/level1/modules --includedir=$ROOT/level1/modules/kernel -Dfm11=1 -DH6309=$H6309 -DNOS9VER=$NOS9VER -DNOS9MAJ=$NOS9MAJ -DNOS9MIN=$NOS9MIN"
AS_RAW="lwasm --no-warn=ifp1 $LWCPU --format=raw --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax"

printf '                    fcc       !FM-11 L1 v39 %s!\n' "$CPU_LABEL" > "$OUT/buildinfo"

build() {
    src=$1
    dst=$2
    shift 2
    # shellcheck disable=SC2086
    $AS_COMMON "$@" --output="$OUT/$dst" "$src"
}

# Build both ROM IPL variants.
# Boot-ROM analysis: both profiles load exactly 512 bytes at $0400.
#   2D:  T0/H0/S1-S2, 2 x 256-byte sectors.  The current disk layout keeps
#        S3-S4 reserved as compatibility/layout margin; it does not enlarge RBF.
#   2HD: T0/H0/S1-S4, 4 x 128-byte native IPL sectors.
# shellcheck disable=SC2086
$AS_RAW --output="$OUT/ipl-2d.bin" "$FM/ipl/ipl_fdd.asm"
# shellcheck disable=SC2086
$AS_RAW --output="$OUT/ipl-2hd.bin" "$FM/ipl/ipl_fdd_2hd.asm"
# shellcheck disable=SC2086
$AS_RAW --output="$OUT/ipl-hd.bin" "$FM/ipl/ipl_hdd.asm"
IPL2HDSIZE=$(wc -c < "$OUT/ipl-2hd.bin" | tr -d ' ')
if [ "$IPL2HDSIZE" -gt 512 ]; then
    echo "ipl-2hd.bin is too large: $IPL2HDSIZE bytes (max 512 for 4x128-byte native IPL sectors)" >&2
    exit 1
fi
IPL2DSIZE=$(wc -c < "$OUT/ipl-2d.bin" | tr -d ' ')
if [ "$IPL2DSIZE" -gt 512 ]; then
    echo "ipl-2d.bin is too large: $IPL2DSIZE bytes (max 512 for 2x256-byte ROM IPL sectors)" >&2
    exit 1
fi
IPLHD_SIZE=$(wc -c < "$OUT/ipl-hd.bin" | tr -d ' ')
if [ "$IPLHD_SIZE" -gt 512 ]; then
    echo "ipl-hd.bin is too large: $IPLHD_SIZE bytes (max 512 for 2x256-byte ROM HDD sectors)" >&2
    exit 1
fi
# Compatibility name: the historical default remains 2D.
cp "$OUT/ipl-2d.bin" "$OUT/ipl.bin"

# Build the external IPL files installed under /SYS/IPL.
# Keep the established on-disk layout unchanged in v37-test2:
#   2D  image passed to SS.FM11IPL remains four 256-byte slots (1024 bytes);
#       only S1-S2 are read by ROM, S3-S4 remain reserved.
#   2HD image is stored in the first four 128-byte native sectors; the extra
#       padding in this build-time buffer is ignored by llfm11.
cp "$OUT/ipl-2d.bin" "$OUT/format-ipl-2d.bin"
cp "$OUT/ipl-2hd.bin" "$OUT/format-ipl-2hd.bin"
truncate -s 1024 "$OUT/format-ipl-2d.bin" "$OUT/format-ipl-2hd.bin"

# Format still embeds the IPL data because it creates the physical sector IDs.
# Cobbler and OS9Gen no longer embed IPL/boottrack data; they read /DD/SYS/IPL
# and /DD/SYS/BOOT at run time.  Convert only the Format copies to FCB source.
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
bin_to_fcb "$OUT/format-ipl-2d.bin"  "$OUT/format-ipl-2d.asm"
bin_to_fcb "$OUT/format-ipl-2hd.bin" "$OUT/format-ipl-2hd.asm"

# FDD-loaded OS9Boot with logical /D0-/D3 and physical /MD0,/MD1,/ND0,/ND1.
# The ROM IPL loads boottrack.bin at $2600.  The Boot module then reads
# OS9Boot from /OS9Boot on floppy drive 0.
# The initial Shell is not resident: SysGo loads /D0/CMDS/Shell.
build "$ROOT/level1/modules/ioman.asm"       ioman
build "$ROOT/level1/modules/rbf.asm"         rbf
build "$ROOT/level1/modules/rbsuper.asm"     rbsuper -Dwildbits=1 -DDrvCount=5
build "$ROOT/level1/modules/scf.asm"         scf
build "$FM/modules/fm11serial.asm"           fm11serial
build "$FM/modules/fm11console.asm"          fm11console
build "$FM/modules/term_fm11.asm"            term_fm11
build "$FM/modules/t1_fm11.asm"              t1_fm11
build "$ROOT/level1/modules/pipeman.asm"     pipeman
build "$ROOT/level1/modules/piper.asm"       piper
build "$ROOT/level1/modules/pipe.asm"        pipe
build "$FM/modules/llfm11.asm"                llfm11 -DDrvCount=5
build "$FM/modules/llfm11hd.asm"              llfm11hd -DDrvCount=5
build "$FM/modules/h0_m2233b_fm11.asm"               h0_m2233b_fm11
build "$FM/modules/h0_m2231b_fm11.asm"        h0_m2231b_fm11
build "$FM/modules/h0_m2230b_fm11.asm"        h0_m2230b_fm11
build "$FM/modules/h0_m2232b_fm11.asm"        h0_m2232b_fm11
build "$FM/modules/h0_m2234b_fm11.asm"        h0_m2234b_fm11
build "$FM/modules/h0_m2235b_fm11.asm"        h0_m2235b_fm11
build "$FM/modules/h0_m2241b_fm11.asm"        h0_m2241b_fm11
build "$FM/modules/h0_m2242b_fm11.asm"        h0_m2242b_fm11
build "$FM/modules/h0_m2243b_fm11.asm"        h0_m2243b_fm11
build "$FM/modules/dd_m2231b_fm11.asm"        dd_m2231b_fm11
build "$FM/modules/dd_m2230b_fm11.asm"        dd_m2230b_fm11
build "$FM/modules/dd_m2232b_fm11.asm"        dd_m2232b_fm11
build "$FM/modules/dd_m2233b_fm11.asm"        dd_m2233b_fm11
build "$FM/modules/dd_m2234b_fm11.asm"        dd_m2234b_fm11
build "$FM/modules/dd_m2235b_fm11.asm"        dd_m2235b_fm11
build "$FM/modules/dd_m2241b_fm11.asm"        dd_m2241b_fm11
build "$FM/modules/dd_m2242b_fm11.asm"        dd_m2242b_fm11
build "$FM/modules/dd_m2243b_fm11.asm"        dd_m2243b_fm11
build "$FM/modules/d0_fm11.asm"               d0_fm11
build "$FM/modules/dd_fm11.asm"               dd_fm11
build "$FM/modules/d1_fm11.asm"               d1_fm11
build "$FM/modules/d2_fm11.asm"               d2_fm11
build "$FM/modules/d3_fm11.asm"               d3_fm11
build "$FM/modules/d0_2hd_fm11.asm"           d0_2hd_fm11
build "$FM/modules/dd_2hd_fm11.asm"           dd_2hd_fm11
build "$FM/modules/d1_2hd_fm11.asm"           d1_2hd_fm11
build "$FM/modules/d2_2hd_fm11.asm"           d2_2hd_fm11
build "$FM/modules/d3_2hd_fm11.asm"           d3_2hd_fm11
build "$FM/modules/md0_fm11.asm"              md0_fm11
build "$FM/modules/md1_fm11.asm"              md1_fm11
build "$FM/modules/nd0_fm11.asm"              nd0_fm11
build "$FM/modules/nd1_fm11.asm"              nd1_fm11
build "$FM/modules/fm11clock.asm"             fm11clock
build "$ROOT/level1/modules/clock2_soft.asm" clock2_soft
build "$ROOT/level1/modules/sysgo.asm"       sysgo -DDD=1

# Build both target-specific Bootp1 images.  Cobbler and OS9Gen load these
# files from /DD/SYS/BOOT.  The active system disk therefore supplies the
# bootstrap assets, while the target medium may be either 2D or 2HD.
build "$FM/modules/boot_fdd.asm"               boot_fdd_2d
build "$FM/modules/boot_fdd_2hd.asm"           boot_fdd_2hd
build "$FM/modules/boot_hdd.asm"               boot_hdd
build "$FM/modules/rel.asm"                    rel
build "$ROOT/level1/modules/kernel/krn.asm"    krn
build "$ROOT/level1/modules/kernel/krnp2.asm"  krnp2
build "$FM/modules/init_fm11.asm"              init

BTMAX=$((0x1080))
BTPHYS=$((17*256))
for profile in 2d 2hd; do
    cat "$OUT/rel" "$OUT/krn" "$OUT/krnp2" "$OUT/init" "$OUT/boot_fdd_$profile" > "$OUT/boottrack-$profile.bin"
    BTSIZE=$(wc -c < "$OUT/boottrack-$profile.bin" | tr -d ' ')
    if [ "$BTSIZE" -gt "$BTMAX" ]; then
        echo "boottrack-$profile.bin is too large: $BTSIZE bytes (max $BTMAX)" >&2
        exit 1
    fi
    truncate -s "$BTMAX" "$OUT/boottrack-$profile.bin"
    cp "$OUT/boottrack-$profile.bin" "$OUT/Bootp1.$(printf '%s' "$profile" | tr '[:lower:]' '[:upper:]')"
    truncate -s "$BTPHYS" "$OUT/Bootp1.$(printf '%s' "$profile" | tr '[:lower:]' '[:upper:]')"
done
cat "$OUT/rel" "$OUT/krn" "$OUT/krnp2" "$OUT/init" "$OUT/boot_hdd" > "$OUT/boottrack-hd.bin"
BTHDSIZE=$(wc -c < "$OUT/boottrack-hd.bin" | tr -d ' ')
if [ "$BTHDSIZE" -gt "$BTMAX" ]; then
    echo "boottrack-hd.bin is too large: $BTHDSIZE bytes (max $BTMAX)" >&2
    exit 1
fi
truncate -s "$BTMAX" "$OUT/boottrack-hd.bin"
cp "$OUT/boottrack-hd.bin" "$OUT/Bootp1.HD"
truncate -s "$BTPHYS" "$OUT/Bootp1.HD"
cp "$OUT/boottrack-2d.bin" "$OUT/boottrack.bin"
cp "$OUT/format-ipl-2d.bin"  "$OUT/IPL.2D"
cp "$OUT/format-ipl-2hd.bin" "$OUT/IPL.2HD"
cp "$OUT/ipl-hd.bin" "$OUT/IPL.HD"
truncate -s 512 "$OUT/IPL.HD"

# Cobbler still embeds only the five logical descriptors for each target
# profile.  IPL and Bootp1 data are external files on /DD.
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
    h0-m2243b:h0_m2243b_fm11 dd-m2243b:dd_m2243b_fm11; do
    tag=${spec%%:*}
    bin=${spec#*:}
    bin_to_fcb "$OUT/$bin" "$OUT/cobbler-$tag.asm"
done

# Standard Level 1 commands selected for the FM-11 distribution.
# Sources under level1/cmds are kept unmodified.  They are copied to the
# build directory only so "use defsfile" resolves to the FM-11 definitions.
#
# BUILDABLE_CMDS: generic Level 1/RBF/SCF utilities that need no FM-11
# hardware-specific source changes in the current tree.
BUILDABLE_CMDS="attr build cmp copy date deiniz del deldir devs dir dmode dump echo error free help ident iniz link list load makdir mdir merge procs prompt rename save setime sleep tee touch tsmon unlink verify dirsort printerr binex exbin disasm edit more minted ded dcheck dsave backup format cobbler os9gen"

# The initial shell is required separately.
cp "$ROOT/level1/cmds/shell_21.asm" "$OUT/shell_21.asm"
for src in $BUILDABLE_CMDS; do
    cp "$ROOT/level1/cmds/$src.asm" "$OUT/$src.asm"
done
(
    cd "$OUT"
    # shellcheck disable=SC2086
    $AS_COMMON --output="$OUT/shell" shell_21.asm
    for cmd in $BUILDABLE_CMDS; do
        # shellcheck disable=SC2086
        $AS_COMMON --output="$OUT/$cmd" "$cmd.asm"
    done

    # pd.asm is the common upstream source for two command variants.
    # It must be assembled with exactly one of PWD/PXD defined.
    cp "$ROOT/level1/cmds/pd.asm" "$OUT/pd.asm"
    # shellcheck disable=SC2086
    $AS_COMMON -DPWD=1 --output="$OUT/pwd" pd.asm
    # shellcheck disable=SC2086
    $AS_COMMON -DPXD=1 --output="$OUT/pxd" pd.asm

    # xmode.asm is also the upstream source for TMode.  Build the SCF
    # path-option variant only; XMODE remains undefined/zero and TMODE=1
    # enables the TMode-specific current-device display code.
    cp "$ROOT/level1/cmds/xmode.asm" "$OUT/xmode.asm"
    # shellcheck disable=SC2086
    $AS_COMMON -DTMODE=1 --output="$OUT/tmode" xmode.asm

    # FM-11-specific diagnostic command for v30 ANSI attribute bring-up.
    cp "$FM/cmds/contest.asm" "$OUT/contest.asm"
    $AS_COMMON --output="$OUT/contest" contest.asm

    # FM-11 MMR/MMU Level 1 diagnostic used for Level 2 bring-up.
    cp "$FM/cmds/mmutest.asm" "$OUT/mmutest.asm"
    $AS_COMMON --output="$OUT/mmutest" mmutest.asm

    # FM-11 MMR task-bank diagnostic used for Level 2 bring-up.
    cp "$FM/cmds/mmutest2.asm" "$OUT/mmutest2.asm"
    $AS_COMMON --output="$OUT/mmutest2" mmutest2.asm
)

make_os9boot() {
    out=$1
    d0=$2
    d1=$3
    d2=$4
    d3=$5
    dd=$6
    cat \
      "$OUT/ioman" \
      "$OUT/rbf" \
      "$OUT/rbsuper" \
      "$OUT/scf" \
      "$OUT/fm11serial" \
      "$OUT/fm11console" \
      "$OUT/term_fm11" \
      "$OUT/t1_fm11" \
      "$OUT/pipeman" \
      "$OUT/piper" \
      "$OUT/pipe" \
      "$OUT/llfm11" \
      "$OUT/$d0" \
      "$OUT/$dd" \
      "$OUT/$d1" \
      "$OUT/$d2" \
      "$OUT/$d3" \
      "$OUT/md0_fm11" \
      "$OUT/md1_fm11" \
      "$OUT/nd0_fm11" \
      "$OUT/nd1_fm11" \
      "$OUT/llfm11hd" \
      "$OUT/h0_m2233b_fm11" \
      "$OUT/fm11clock" \
      "$OUT/clock2_soft" \
      "$OUT/sysgo" \
      > "$OUT/$out"
    BOOTSIZE=$(wc -c < "$OUT/$out" | tr -d ' ')
    if [ "$BOOTSIZE" -gt 65535 ]; then
        echo "$out is too large for Level 1 fragmented boot: $BOOTSIZE bytes" >&2
        exit 1
    fi
    echo "$out size: $BOOTSIZE bytes"
}

# 2D boot profile: D0,D1 are MD0,MD1; D2,D3 are ND0,ND1.
make_os9boot OS9Boot-2d d0_fm11 d1_fm11 d2_fm11 d3_fm11 dd_fm11
# 2HD boot profile: D0,D1 are ND0,ND1; D2,D3 are MD0,MD1.
make_os9boot OS9Boot-2hd d0_2hd_fm11 d1_2hd_fm11 d2_2hd_fm11 d3_2hd_fm11 dd_2hd_fm11
# Compatibility name remains the 2D profile.
cp "$OUT/OS9Boot-2d" "$OUT/OS9Boot"


echo "2D IPL:         $OUT/ipl-2d.bin"
echo "2HD IPL:        $OUT/ipl-2hd.bin"
echo "2D Bootp1:      $OUT/Bootp1.2D"
echo "2HD Bootp1:     $OUT/Bootp1.2HD"
echo "HDD IPL:         $OUT/IPL.HD"
echo "HDD Bootp1:      $OUT/Bootp1.HD"
echo "2D OS9Boot:     $OUT/OS9Boot-2d  (/D0,/D1=MD0,MD1; /D2,/D3=ND0,ND1)"
echo "2HD OS9Boot:    $OUT/OS9Boot-2hd (/D0,/D1=ND0,ND1; /D2,/D3=MD0,MD1)"
echo "Physical names: /MD0 /MD1 = 5-inch 2D; /ND0 /ND1 = 5-inch 2HD"
echo "FD commands built: Shell $BUILDABLE_CMDS pwd pxd"
echo "CPU target:       $CPU_LABEL"
