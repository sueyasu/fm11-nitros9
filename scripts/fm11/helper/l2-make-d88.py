#!/usr/bin/env python3
"""Build FM-11 NitrOS-9 Level 2 2D or 2HD D88 images."""

from pathlib import Path
import argparse
import struct

HEADER_SIZE = 0x2B0
TRACK_TABLE_ENTRIES = 164
KERNEL_SECTORS = 21
KERNEL_SIZE = KERNEL_SECTORS * 256

PROFILES = {
    "2d": {
        "cylinders": 40,
        "spt": 16,
        "rbf_cylinders": 39,
        "disk_type": 0x00,
    },
    "2hd": {
        "cylinders": 77,
        "spt": 26,
        "rbf_cylinders": 76,
        "disk_type": 0x20,
    },
}


def sector_header(cyl, side, sector, n, sectors, density, size):
    return struct.pack(
        "<BBBBHBBB5sH",
        cyl, side, sector, n, sectors,
        density, 0, 0, b"\0" * 5, size,
    )


def make_track(cyl, side, sectors):
    """sectors: iterable of (payload, N, density)."""
    entries = list(sectors)
    body = bytearray()
    count = len(entries)
    for index, (payload, n, density) in enumerate(entries, 1):
        size = len(payload)
        body += sector_header(cyl, side, index, n, count, density, size)
        body += payload
    return bytes(body)


def split_fixed(data, count, size):
    if len(data) != count * size:
        raise SystemExit(
            f"payload is {len(data)} bytes; expected {count * size}"
        )
    return [data[i * size:(i + 1) * size] for i in range(count)]


def build_2d(rbf_data, ipl_data, kernel):
    if len(ipl_data) > 512:
        raise SystemExit(f"2D IPL is too large: {len(ipl_data)} bytes")

    boot = ipl_data.ljust(4 * 256, b"\0") + kernel
    boot = boot.ljust(2 * 16 * 256, b"\0")
    if len(boot) != 2 * 16 * 256:
        raise SystemExit("2D IPL + kernel track does not fit cylinder 0")

    tracks = []
    for side in range(2):
        payload = boot[side * 16 * 256:(side + 1) * 16 * 256]
        sectors = [(s, 1, 0x00) for s in split_fixed(payload, 16, 256)]
        tracks.append((0, side, make_track(0, side, sectors)))

    pos = 0
    for cyl in range(1, 40):
        for side in range(2):
            nbytes = 16 * 256
            payload = rbf_data[pos:pos + nbytes]
            if len(payload) != nbytes:
                raise SystemExit("short 2D RBF payload")
            sectors = [(s, 1, 0x00) for s in split_fixed(payload, 16, 256)]
            tracks.append((cyl, side, make_track(cyl, side, sectors)))
            pos += nbytes
    return tracks, pos


def build_2hd(rbf_data, ipl_data, kernel):
    if len(ipl_data) > 4 * 128:
        raise SystemExit(f"2HD IPL is too large: {len(ipl_data)} bytes")

    # Native FM-11 2HD boot cylinder:
    # T0/H0 = 26 x 128-byte FM, ROM IPL in S1-S4.
    # T0/H1 = 26 x 256-byte MFM, REL/Boot/Krn in S1-S21.
    h0 = ipl_data.ljust(26 * 128, b"\0")
    h1 = kernel.ljust(26 * 256, b"\0")
    tracks = [
        (
            0, 0,
            make_track(
                0, 0,
                [(s, 0, 0x40) for s in split_fixed(h0, 26, 128)],
            ),
        ),
        (
            0, 1,
            make_track(
                0, 1,
                [(s, 1, 0x00) for s in split_fixed(h1, 26, 256)],
            ),
        ),
    ]

    pos = 0
    for cyl in range(1, 77):
        for side in range(2):
            nbytes = 26 * 256
            payload = rbf_data[pos:pos + nbytes]
            if len(payload) != nbytes:
                raise SystemExit("short 2HD RBF payload")
            sectors = [(s, 1, 0x00) for s in split_fixed(payload, 26, 256)]
            tracks.append((cyl, side, make_track(cyl, side, sectors)))
            pos += nbytes
    return tracks, pos


def make_d88(media, rbf, ipl, kerneltrack, output, label):
    profile = PROFILES[media]
    rbf_data = rbf.read_bytes()
    expected_rbf = (
        profile["rbf_cylinders"] * 2 * profile["spt"] * 256
    )
    if len(rbf_data) != expected_rbf:
        raise SystemExit(
            f"RBF size is {len(rbf_data)} bytes; expected "
            f"{expected_rbf} for {media}"
        )

    ipl_data = ipl.read_bytes()
    kernel = kerneltrack.read_bytes()
    if len(kernel) != KERNEL_SIZE:
        raise SystemExit(
            f"kernel track is {len(kernel)} bytes; expected {KERNEL_SIZE}"
        )

    if media == "2d":
        tracks, used = build_2d(rbf_data, ipl_data, kernel)
    else:
        tracks, used = build_2hd(rbf_data, ipl_data, kernel)
    if used != len(rbf_data):
        raise SystemExit("RBF payload size mismatch")

    offsets = [0] * TRACK_TABLE_ENTRIES
    body = bytearray()
    for cyl, side, track in tracks:
        index = cyl * 2 + side
        offsets[index] = HEADER_SIZE + len(body)
        body += track

    header = bytearray(HEADER_SIZE)
    disk_name = label.encode("ascii", "replace")[:16]
    header[:len(disk_name)] = disk_name
    header[0x1A] = 0
    header[0x1B] = profile["disk_type"]
    total_size = HEADER_SIZE + len(body)
    struct.pack_into("<I", header, 0x1C, total_size)
    for i, off in enumerate(offsets):
        struct.pack_into("<I", header, 0x20 + i * 4, off)

    output.write_bytes(header + body)
    print(f"Created {output}: FM-11 Level 2 {media.upper()}, "
          f"D88 size {total_size}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rbf", type=Path)
    ap.add_argument("ipl", type=Path)
    ap.add_argument("kerneltrack", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--media", choices=sorted(PROFILES), required=True)
    ap.add_argument("--label", default="FM11 NOS9 L2")
    args = ap.parse_args()
    make_d88(
        args.media, args.rbf, args.ipl, args.kerneltrack,
        args.output, args.label,
    )


if __name__ == "__main__":
    main()
