#!/usr/bin/env python3
"""Build the initial FM-11 NitrOS-9 Level 2 2D D88 image.

Level 2 reserves T0/H0/S1-S4 for the ROM IPL and uses the following
21 sectors for the $1200-byte REL/Boot/Krn kernel track:
  T0/H0/S5-S16 (12 sectors)
  T0/H1/S1-S9  (9 sectors)

RBF logical sector 0 begins at physical T1/H0/S1.
"""

from pathlib import Path
import argparse
import struct

HEADER_SIZE = 0x2B0
TRACK_TABLE_ENTRIES = 164
SECTOR_SIZE = 256
CYLINDERS = 40
SIDES = 2
SPT = 16
RBF_SIZE = 39 * 2 * 16 * SECTOR_SIZE
IPL_SLOTS = 4
KERNEL_SECTORS = 21


def build_tracks(rbf: Path, ipl: Path, kerneltrack: Path):
    rbf_data = rbf.read_bytes()
    if len(rbf_data) != RBF_SIZE:
        raise SystemExit(
            f"RBF size is {len(rbf_data)} bytes; expected {RBF_SIZE}"
        )

    ipl_data = ipl.read_bytes()
    if len(ipl_data) > 2 * SECTOR_SIZE:
        raise SystemExit(
            f"IPL is too large: {len(ipl_data)} bytes "
            f"(ROM loads at most 512 bytes)"
        )
    ipl_area = ipl_data.ljust(IPL_SLOTS * SECTOR_SIZE, b"\0")

    kernel = kerneltrack.read_bytes()
    expect_kernel = KERNEL_SECTORS * SECTOR_SIZE
    if len(kernel) != expect_kernel:
        raise SystemExit(
            f"kernel track is {len(kernel)} bytes; expected {expect_kernel}"
        )

    boot_cyl = (ipl_area + kernel).ljust(
        SIDES * SPT * SECTOR_SIZE, b"\0"
    )
    if len(boot_cyl) > SIDES * SPT * SECTOR_SIZE:
        raise SystemExit("IPL + Level 2 kernel track does not fit cylinder 0")

    tracks = [
        (0, 0, boot_cyl[:SPT * SECTOR_SIZE]),
        (0, 1, boot_cyl[SPT * SECTOR_SIZE:]),
    ]

    pos = 0
    for cyl in range(1, CYLINDERS):
        for side in range(SIDES):
            n = SPT * SECTOR_SIZE
            payload = rbf_data[pos:pos + n]
            if len(payload) != n:
                raise SystemExit("short RBF payload while building D88")
            tracks.append((cyl, side, payload))
            pos += n

    if pos != len(rbf_data):
        raise SystemExit("RBF payload size mismatch")
    return tracks


def make_d88(rbf: Path, ipl: Path, kerneltrack: Path,
             output: Path, label: str):
    tracks = build_tracks(rbf, ipl, kerneltrack)
    offsets = [0] * TRACK_TABLE_ENTRIES
    body = bytearray()

    for idx, (cyl, side, payload) in enumerate(tracks):
        offsets[idx] = HEADER_SIZE + len(body)
        pos = 0
        for sector in range(1, SPT + 1):
            body += struct.pack(
                "<BBBBHBBB5sH",
                cyl, side, sector, 1, SPT,
                0x00, 0, 0, b"\0" * 5, SECTOR_SIZE
            )
            body += payload[pos:pos + SECTOR_SIZE]
            pos += SECTOR_SIZE

    header = bytearray(HEADER_SIZE)
    disk_name = label.encode("ascii", "replace")[:16]
    header[:len(disk_name)] = disk_name
    header[0x1A] = 0          # write protect
    header[0x1B] = 0x00       # 2D
    total_size = HEADER_SIZE + len(body)
    struct.pack_into("<I", header, 0x1C, total_size)
    for i, off in enumerate(offsets):
        struct.pack_into("<I", header, 0x20 + i * 4, off)

    output.write_bytes(header + body)
    print(f"Created {output}: FM-11 Level 2 2D, D88 size {total_size}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rbf", type=Path)
    ap.add_argument("ipl", type=Path)
    ap.add_argument("kerneltrack", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--label", default="FM11 NOS9 L2 2D")
    args = ap.parse_args()
    make_d88(args.rbf, args.ipl, args.kerneltrack,
             args.output, args.label)


if __name__ == "__main__":
    main()
