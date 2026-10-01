#!/usr/bin/env python3
"""Set an RBF disk's DD.BT to the file descriptor of /OS9Boot.

The standard NitrOS-9 boot_common fragmented-boot path is selected by
setting DD.BSZ to zero.  DD.BT then points to the RBF file descriptor
sector, whose segment list describes the actual OS9Boot data sectors.
"""
from pathlib import Path
import sys

SECTOR = 256
DD_DIR = 0x08
DD_BT  = 0x15
DD_BSZ = 0x18
FD_SIZ = 0x09
FD_SEG = 0x10
DIR_REC = 32
DIR_NAME = 29


def be16(b):
    return (b[0] << 8) | b[1]


def be24(b):
    return (b[0] << 16) | (b[1] << 8) | b[2]


def put24(buf, off, value):
    buf[off:off+3] = bytes(((value >> 16) & 0xff,
                            (value >> 8) & 0xff,
                            value & 0xff))


def decode_os9_name(raw):
    out = bytearray()
    for c in raw:
        if c == 0:
            break
        out.append(c & 0x7f)
        if c & 0x80:
            break
    return out.decode('ascii', errors='replace')


def read_fd(data, lsn):
    off = lsn * SECTOR
    if off + SECTOR > len(data):
        raise ValueError(f'FD LSN {lsn} is outside image')
    return data[off:off+SECTOR]


def fd_segments(fd):
    for off in range(FD_SEG, SECTOR - 4, 5):
        start = be24(fd[off:off+3])
        count = be16(fd[off+3:off+5])
        if start == 0 or count == 0:
            break
        yield start, count


def read_file(data, fd):
    size = int.from_bytes(fd[FD_SIZ:FD_SIZ+4], 'big')
    out = bytearray()
    for start, count in fd_segments(fd):
        a = start * SECTOR
        b = (start + count) * SECTOR
        if b > len(data):
            raise ValueError('file segment outside image')
        out.extend(data[a:b])
        if len(out) >= size:
            break
    return bytes(out[:size])


def main():
    if len(sys.argv) != 2:
        raise SystemExit(f'usage: {sys.argv[0]} IMAGE')
    path = Path(sys.argv[1])
    data = bytearray(path.read_bytes())
    if len(data) < SECTOR:
        raise SystemExit('image is too small')

    root_fd_lsn = be24(data[DD_DIR:DD_DIR+3])
    if root_fd_lsn == 0:
        raise SystemExit('invalid RBF root directory FD LSN')
    root_fd = read_fd(data, root_fd_lsn)
    directory = read_file(data, root_fd)

    boot_fd_lsn = None
    for off in range(0, len(directory) - DIR_REC + 1, DIR_REC):
        ent = directory[off:off+DIR_REC]
        name = decode_os9_name(ent[:DIR_NAME])
        fd_lsn = be24(ent[DIR_NAME:DIR_NAME+3])
        if name.lower() == 'os9boot':
            boot_fd_lsn = fd_lsn
            break

    if not boot_fd_lsn:
        raise SystemExit('/OS9Boot not found in root directory')

    boot_fd = read_fd(data, boot_fd_lsn)
    boot_size = int.from_bytes(boot_fd[FD_SIZ:FD_SIZ+4], 'big')
    if boot_size == 0 or boot_size > 65535:
        raise SystemExit(f'invalid OS9Boot size: {boot_size}')
    segs = list(fd_segments(boot_fd))
    if not segs:
        raise SystemExit('OS9Boot has no data segments')

    put24(data, DD_BT, boot_fd_lsn)
    data[DD_BSZ:DD_BSZ+2] = b'\x00\x00'
    path.write_bytes(data)

    print(f'Patched DD.BT -> OS9Boot FD LSN {boot_fd_lsn}')
    print(f'OS9Boot size: {boot_size} bytes')
    print('OS9Boot segments: ' + ', '.join(f'{s}+{n}' for s, n in segs))

if __name__ == '__main__':
    main()
