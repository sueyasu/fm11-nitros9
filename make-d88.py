#!/usr/bin/env python3
"""Build an FM-11 D88 image directly from an editable RBF master.

The caller supplies the already FM-11-patched temporary RBF copy together
with the appropriate IPL and boottrack.  No persistent raw .img file is
created.
"""

from pathlib import Path
import argparse
import struct

HEADER_SIZE = 0x2B0
TRACK_TABLE_ENTRIES = 164
SECTOR_SIZE = 256

PROFILES = {
    "2d": {
        "name": "2D",
        "cylinders": 40,
        "sides": 2,
        "spt": 16,
        "media": 0x00,
        "density": 0x00,
        "rbf_size": 39 * 2 * 16 * 256,
    },
    "2hd": {
        "name": "2HD",
        "cylinders": 77,
        "sides": 2,
        "spt": 26,
        "media": 0x20,
        "density": 0x00,
        "rbf_size": 76 * 2 * 26 * 256,
    },
}


def sector_header(cyl, side, sector, count, density):
    return struct.pack(
        "<BBBBHBBB5sH",
        cyl,
        side,
        sector,
        1,  # N=1 => 256-byte sector
        count,
        density,
        0,
        0,
        b"\0" * 5,
        SECTOR_SIZE,
    )


def build_sector_payloads(profile, rbf, ipl, boottrack):
    p = PROFILES[profile]
    rbf_data = rbf.read_bytes()
    if len(rbf_data) != p["rbf_size"]:
        raise SystemExit(
            f"{profile} RBF size is {len(rbf_data)} bytes; expected {p['rbf_size']}"
        )

    ipl_data = ipl.read_bytes()
    bt_data = boottrack.read_bytes()
    if len(bt_data) > 17 * 256:
        raise SystemExit(f"boottrack is too large: {len(bt_data)} bytes")
    bt_data = bt_data.ljust(17 * 256, b"\0")

    tracks = []
    if profile == "2hd":
        # Native FM-11 OS-9 2HD: T0/H0 is 26x128-byte FM.
        if len(ipl_data) > 4 * 128:
            raise SystemExit(f"2HD IPL is too large: {len(ipl_data)} bytes (max 512)")
        h0 = ipl_data.ljust(26 * 128, b"\0")
        tracks.append((0, 0, 128, h0))
        h1 = bt_data.ljust(26 * 256, b"\0")
        tracks.append((0, 1, 256, h1))
    else:
        if len(ipl_data) > 4 * 256:
            raise SystemExit(f"2D IPL is too large: {len(ipl_data)} bytes")
        boot = (ipl_data.ljust(4 * 256, b"\0") + bt_data).ljust(2 * 16 * 256, b"\0")
        tracks.append((0, 0, 256, boot[:16 * 256]))
        tracks.append((0, 1, 256, boot[16 * 256:]))

    pos = 0
    for cyl in range(1, p["cylinders"]):
        for side in range(2):
            n = p["spt"] * 256
            tracks.append((cyl, side, 256, rbf_data[pos:pos+n]))
            pos += n
    return tracks


def make_d88(profile, rbf, ipl, boottrack, dst, label=None):
    p = PROFILES[profile]
    tracks = build_sector_payloads(profile, rbf, ipl, boottrack)
    offsets = [0] * TRACK_TABLE_ENTRIES
    body = bytearray()

    for idx, (cyl, side, ssize, payload) in enumerate(tracks):
        offsets[idx] = HEADER_SIZE + len(body)
        spt = len(payload) // ssize
        ncode = {128: 0, 256: 1, 512: 2, 1024: 3}[ssize]
        density = 0x40 if (profile == "2hd" and cyl == 0 and side == 0) else p["density"]
        pos = 0
        for r in range(1, spt + 1):
            hdr = struct.pack("<BBBBHBBB5sH", cyl, side, r, ncode, spt,
                              density, 0, 0, b"\0" * 5, ssize)
            body += hdr
            body += payload[pos:pos+ssize]
            pos += ssize

    header = bytearray(HEADER_SIZE)
    disk_name = (label or f"FM11 NitrOS9 {p['name']}").encode("ascii", "replace")[:16]
    header[:len(disk_name)] = disk_name
    header[0x1A] = 0
    header[0x1B] = p["media"]
    total_size = HEADER_SIZE + len(body)
    struct.pack_into("<I", header, 0x1C, total_size)
    for i, off in enumerate(offsets):
        struct.pack_into("<I", header, 0x20 + i * 4, off)
    dst.write_bytes(header + body)
    print(f"Created {dst}: {p['name']} native FM-11 layout, D88 size {total_size}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("profile", choices=sorted(PROFILES))
    ap.add_argument("rbf", type=Path)
    ap.add_argument("ipl", type=Path)
    ap.add_argument("boottrack", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--label")
    args = ap.parse_args()
    make_d88(args.profile, args.rbf, args.ipl, args.boottrack, args.output, args.label)


if __name__ == "__main__":
    main()
