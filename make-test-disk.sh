#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CPU=${1:-}
case "$CPU" in
    6809|6309) ;;
    *) echo "usage: $0 6809|6309 [all|2d|2hd]" >&2; exit 2 ;;
esac
shift
OUT="$ROOT/level1/fm11/build-minimal-$CPU"
SECTOR=256

if ! command -v os9 >/dev/null 2>&1; then
    echo "ToolShed 'os9' command is required" >&2
    exit 1
fi

usage() {
    echo "usage: $0 6809|6309 [all|2d|2hd]" >&2
    exit 2
}

MODE=${1:-all}
case "$MODE" in
    all|2d|2hd) ;;
    *) usage ;;
esac

# Commands that make the distribution usable even on the small 2D image.
CORE_CMDS="shell dir list echo copy del makdir attr rename mdir free ident date procs tee minted mmutest mmutest2"
# Other generic Level 1 commands currently built without FM-11-specific changes.
EXTRA_CMDS="build cmp deiniz deldir devs dmode dump error help iniz link load merge prompt save setime sleep touch tsmon unlink verify dirsort pwd pxd printerr binex exbin disasm edit more contest ded dcheck dsave tmode backup format cobbler os9gen"
ALL_CMDS="$CORE_CMDS $EXTRA_CMDS"

# OS9Gen source modules installed under /SYS/MODULES.  Both logical-drive
# profiles are retained on every system disk so either 2D or 2HD target media
# can be generated regardless of the profile used to boot the running system.
BOOT_MODULES_COMMON="ioman rbf rbsuper scf fm11serial fm11console term_fm11 t1_fm11 pipeman piper pipe llfm11 md0_fm11 md1_fm11 nd0_fm11 nd1_fm11 llfm11hd fm11clock clock2_soft sysgo"
# h0_m2233b_fm11 is the default M2233B descriptor.  Keep it separate from the
# alternate H0 descriptors so its two roles are explicit: it is resident in
# the standard OS9Boot and is also always stored in /SYS/MODULES for OS9Gen.
HDD_MODULE_DEFAULT="h0_m2233b_fm11"
HDD_MODULE_ALTERNATES="h0_m2231b_fm11 h0_m2230b_fm11 h0_m2232b_fm11 h0_m2234b_fm11 h0_m2235b_fm11 h0_m2241b_fm11 h0_m2242b_fm11 h0_m2243b_fm11"
HDD_DD_MODULES="dd_m2231b_fm11 dd_m2230b_fm11 dd_m2232b_fm11 dd_m2233b_fm11 dd_m2234b_fm11 dd_m2235b_fm11 dd_m2241b_fm11 dd_m2242b_fm11 dd_m2243b_fm11"
BOOT_MODULES_2D="d0_fm11 dd_fm11 d1_fm11 d2_fm11 d3_fm11"
BOOT_MODULES_2HD="d0_2hd_fm11 dd_2hd_fm11 d1_2hd_fm11 d2_2hd_fm11 d3_2hd_fm11"
BOOT_MODULES="$BOOT_MODULES_COMMON $HDD_MODULE_DEFAULT $HDD_MODULE_ALTERNATES $HDD_DD_MODULES $BOOT_MODULES_2D $BOOT_MODULES_2HD"

for f in $ALL_CMDS; do
    if [ ! -f "$OUT/$f" ]; then
        echo "Missing $OUT/$f; run ./build-minimal.sh first" >&2
        exit 1
    fi
done

cap_name() {
    case "$1" in
        shell) echo Shell ;; dir) echo Dir ;; list) echo List ;; echo) echo Echo ;;
        copy) echo Copy ;; del) echo Del ;; makdir) echo MakDir ;; attr) echo Attr ;;
        rename) echo Rename ;; mdir) echo MDir ;; free) echo Free ;; ident) echo Ident ;;
        date) echo Date ;; procs) echo Procs ;; tee) echo Tee ;; build) echo Build ;;
        cmp) echo Cmp ;; deiniz) echo Deiniz ;; deldir) echo Deldir ;; devs) echo Devs ;;
        dmode) echo DMode ;; dump) echo Dump ;; error) echo Error ;; help) echo Help ;;
        iniz) echo Iniz ;; link) echo Link ;; load) echo Load ;; merge) echo Merge ;;
        prompt) echo Prompt ;; save) echo Save ;; setime) echo Setime ;; sleep) echo Sleep ;;
        touch) echo Touch ;; tsmon) echo Tsmon ;; unlink) echo Unlink ;; verify) echo Verify ;;
        dirsort) echo DirSort ;; pwd) echo Pwd ;; pxd) echo Pxd ;; printerr) echo Printerr ;;
        binex) echo Binex ;; exbin) echo Exbin ;; disasm) echo Disasm ;; edit) echo Edit ;;
        more) echo More ;; ded) echo dEd ;; dcheck) echo DCheck ;; dsave) echo DSave ;; tmode) echo TMode ;; backup) echo Backup ;; format) echo Format ;; cobbler) echo Cobbler ;; os9gen) echo OS9Gen ;;
        minted) echo MinTED ;;
        contest) echo ConTest ;;
        mmutest) echo MMUTest ;;
        mmutest2) echo MMUTest2 ;;
        *) echo "$1" ;;
    esac
}

copy_cmd() {
    rbf=$1
    cmd=$2
    name=$(cap_name "$cmd")
    os9 copy -o=0 "$OUT/$cmd" "$rbf,CMDS/$name"
    os9 attr "$rbf,CMDS/$name" -e -pe >/dev/null
}

install_sys_contents() {
    rbf=$1
    shift
    sys_tmp=$(mktemp -d "${TMPDIR:-/tmp}/fm11-sys.XXXXXX")
    trap 'rm -rf "$sys_tmp"' EXIT HUP INT TERM

    python3 "$ROOT/make-sys-files.py" \
        --sysdir "$ROOT/level1/sys" \
        --outdir "$sys_tmp" "$@"

    os9 makdir "$rbf,SYS"
    for f in errmsg helpmsg password motd modem.conf; do
        os9 copy -o=0 "$sys_tmp/$f" "$rbf,SYS/$f"
    done

    rm -rf "$sys_tmp"
    trap - EXIT HUP INT TERM
}

install_os9gen_assets() {
    rbf=$1

    os9 makdir "$rbf,SYS/MODULES"
    for module in $BOOT_MODULES_COMMON $BOOT_MODULES_2D $BOOT_MODULES_2HD; do
        os9 copy -o=0 "$OUT/$module" "$rbf,SYS/MODULES/$module"
    done

    # Always retain the default M2233B H0 descriptor as an OS9Gen source,
    # even though the same module is already resident in the standard OS9Boot.
    os9 copy -o=0 "$OUT/$HDD_MODULE_DEFAULT" \
        "$rbf,SYS/MODULES/$HDD_MODULE_DEFAULT"

    # Alternative emulator-supported H0 geometries are source modules only;
    # they are not part of the default OS9Boot.
    for module in $HDD_MODULE_ALTERNATES $HDD_DD_MODULES; do
        os9 copy -o=0 "$OUT/$module" "$rbf,SYS/MODULES/$module"
    done

    # FM-11 boot-controller assets are data files, not part of Cobbler/OS9Gen.
    # /DD keeps the source bound to the currently booted system disk even when
    # the target of Cobbler/OS9Gen is another floppy.
    os9 makdir "$rbf,SYS/IPL"
    os9 makdir "$rbf,SYS/BOOT"
    os9 copy -o=0 "$OUT/IPL.2D"     "$rbf,SYS/IPL/IPL.2D"
    os9 copy -o=0 "$OUT/IPL.2HD"    "$rbf,SYS/IPL/IPL.2HD"
    os9 copy -o=0 "$OUT/IPL.HD"     "$rbf,SYS/IPL/IPL.HD"
    os9 copy -o=0 "$OUT/Bootp1.2D"  "$rbf,SYS/BOOT/Bootp1.2D"
    os9 copy -o=0 "$OUT/Bootp1.2HD" "$rbf,SYS/BOOT/Bootp1.2HD"
    os9 copy -o=0 "$OUT/Bootp1.HD"  "$rbf,SYS/BOOT/Bootp1.HD"

    # OS-9 I$ReadLn expects carriage-return terminated text.  Keep the
    # source boot lists host-friendly (LF) and convert them to CR-only when
    # installing them into the RBF image.
    bl2d=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist2d.XXXXXX")
    bl2hd=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist2hd.XXXXXX")
    blhd=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlisthd.XXXXXX")
    trap 'rm -f "$bl2d" "$bl2hd" "$blhd"' EXIT HUP INT TERM
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.2d" > "$bl2d"
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.2hd" > "$bl2hd"
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd" > "$blhd"
    os9 copy -o=0 "$bl2d"  "$rbf,SYS/bootlist.2d"
    os9 copy -o=0 "$bl2hd" "$rbf,SYS/bootlist.2hd"
    os9 copy -o=0 "$blhd"  "$rbf,SYS/bootlist.hd"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2231b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2231b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2231b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2230b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2230b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2230b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2232b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2232b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2232b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2233b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2233b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2233b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2234b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2234b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2234b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2235b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2235b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2235b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2241b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2241b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2241b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2242b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2242b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2242b"
    rm -f "$blx"
    blx=$(mktemp "${TMPDIR:-/tmp}/fm11-bootlist-m2243b.XXXXXX")
    tr '\n' '\r' < "$ROOT/level1/fm11/bootlists/bootlist.hd.m2243b" > "$blx"
    os9 copy -o=0 "$blx" "$rbf,SYS/bootlist.hd.m2243b"
    rm -f "$blx"
    rm -f "$bl2d" "$bl2hd" "$blhd"
    trap - EXIT HUP INT TERM
}

boot_assets_size() {
    total=0
    for module in $BOOT_MODULES; do
        sz=$(wc -c < "$OUT/$module" | tr -d ' ')
        total=$((total + sz))
    done
    for list in "$ROOT/level1/fm11/bootlists/bootlist.2d" "$ROOT/level1/fm11/bootlists/bootlist.2hd" "$ROOT/level1/fm11/bootlists/bootlist.hd" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2231b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2230b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2232b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2233b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2234b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2235b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2241b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2242b" "$ROOT/level1/fm11/bootlists/bootlist.hd.m2243b"; do
        sz=$(wc -c < "$list" | tr -d ' ')
        total=$((total + sz))
    done
    for asset in IPL.2D IPL.2HD IPL.HD Bootp1.2D Bootp1.2HD Bootp1.HD; do
        sz=$(wc -c < "$OUT/$asset" | tr -d ' ')
        total=$((total + sz))
    done
    echo "$total"
}

install_rbf_contents() {
    rbf=$1
    os9boot=$2
    profile=$3

    os9 copy -o=0 "$os9boot" "$rbf,OS9Boot"
    os9 makdir "$rbf,CMDS"

    installed_cmds="$CORE_CMDS"
    for cmd in $CORE_CMDS; do
        copy_cmd "$rbf" "$cmd"
    done

    if [ "$profile" = 2hd ]; then
        # 2HD has ample room: install every currently selected generic command.
        for cmd in $EXTRA_CMDS; do
            copy_cmd "$rbf" "$cmd"
        done
        installed_cmds="$ALL_CMDS"
    else
        # 2D is only 319488 bytes.  Measure the actual binaries first.
        # If the complete selected command set fits the conservative payload
        # budget, install all of it.  Otherwise keep only the core set.
        limit=285000
        all_used=$(wc -c < "$os9boot" | tr -d ' ')
        assets_used=$(boot_assets_size)
        all_used=$((all_used + assets_used))
        for cmd in $ALL_CMDS; do
            sz=$(wc -c < "$OUT/$cmd" | tr -d ' ')
            all_used=$((all_used + sz))
        done
        if [ "$all_used" -le "$limit" ]; then
            for cmd in $EXTRA_CMDS; do
                copy_cmd "$rbf" "$cmd"
            done
            installed_cmds="$ALL_CMDS"
            echo "2D: complete command set selected (payload about $all_used bytes)"
        else
            core_used=$(wc -c < "$os9boot" | tr -d ' ')
            core_used=$((core_used + assets_used))
            for cmd in $CORE_CMDS; do
                sz=$(wc -c < "$OUT/$cmd" | tr -d ' ')
                core_used=$((core_used + sz))
            done
            if [ "$core_used" -gt "$limit" ]; then
                echo "2D core payload is unexpectedly too large: $core_used bytes" >&2
                exit 1
            fi
            echo "2D: complete set is about $all_used bytes; install core set only (about $core_used bytes)"
        fi
    fi

    # /DD/SYS data used by Error/Help and the multi-user/login environment.
    install_sys_contents "$rbf" $installed_cmds

    # Standard OS9Gen inputs.  Boot lists live directly in /SYS and all
    # constituent modules live in /SYS/MODULES.
    install_os9gen_assets "$rbf"

    # DD.BT/DD.BSZ belong to the filesystem and remain ToolShed-compatible.
    "$ROOT/patch-boot-descriptor.py" "$rbf"
}

make_2d() {
    rbf="$ROOT/fm11-system-$CPU-2d.rbf"
    rbf_sectors=$((39*2*16))
    [ -f "$OUT/OS9Boot-2d" ] || { echo "Missing $OUT/OS9Boot-2d" >&2; exit 1; }
    rm -f "$rbf"
    os9 format -e -l"$rbf_sectors" -bs"$SECTOR" -q "$rbf" -n"FM11SYS"
    install_rbf_contents "$rbf" "$OUT/OS9Boot-2d" 2d
    size=$(wc -c < "$rbf" | tr -d ' ')
    [ "$size" -eq $((rbf_sectors*SECTOR)) ] || { echo "2D RBF image size error: $size" >&2; exit 1; }
    echo "Created editable ToolShed image: $rbf ($size bytes)"
    echo "  profile: /D0=/MD0 /D1=/MD1 /D2=/ND0 /D3=/ND1"
}

make_2hd() {
    rbf="$ROOT/fm11-system-$CPU-2hd.rbf"
    rbf_sectors=$((76*2*26))
    [ -f "$OUT/OS9Boot-2hd" ] || { echo "Missing $OUT/OS9Boot-2hd" >&2; exit 1; }
    rm -f "$rbf"
    os9 format -e -l"$rbf_sectors" -bs"$SECTOR" -q "$rbf" -n"FM11SYS"
    install_rbf_contents "$rbf" "$OUT/OS9Boot-2hd" 2hd
    size=$(wc -c < "$rbf" | tr -d ' ')
    [ "$size" -eq $((rbf_sectors*SECTOR)) ] || { echo "2HD RBF image size error: $size" >&2; exit 1; }
    echo "Created editable ToolShed image: $rbf ($size bytes)"
    echo "  profile: /D0=/ND0 /D1=/ND1 /D2=/MD0 /D3=/MD1"
}

case "$MODE" in
    2d) make_2d ;;
    2hd) make_2hd ;;
    all) make_2d; make_2hd ;;
esac

echo "Edit the .rbf master image(s) directly with ToolShed, then run:"
echo "  ./make-fm11-image.sh $CPU"
