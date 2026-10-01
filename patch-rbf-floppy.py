#!/usr/bin/env python3
"""Patch a ToolShed -l RBF image with FM-11 floppy geometry.

Usage: patch-rbf-floppy.py IMAGE [2d|2hd]
"""
from pathlib import Path
import sys

SECTOR = 256
DD_TOT = 0x00
DD_TKS = 0x03
DD_FMT = 0x10
DD_SPT = 0x11

PROFILES = {
    '2d':  dict(sectors=39*2*16, spt=16, fmt=0x03),
    '2hd': dict(sectors=76*2*26, spt=26, fmt=0x03),
}

def put24(buf, off, value):
    buf[off:off+3] = bytes(((value >> 16) & 0xff,
                            (value >> 8) & 0xff,
                            value & 0xff))

def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit(f'usage: {sys.argv[0]} RBF_IMAGE [2d|2hd]')
    path = Path(sys.argv[1])
    profile = sys.argv[2].lower() if len(sys.argv) == 3 else '2d'
    if profile not in PROFILES:
        raise SystemExit(f'unknown profile: {profile}')
    g = PROFILES[profile]
    data = bytearray(path.read_bytes())
    expect = g['sectors'] * SECTOR
    if len(data) != expect:
        raise SystemExit(f'RBF image is {len(data)} bytes, expected {expect} for {profile}')
    put24(data, DD_TOT, g['sectors'])
    data[DD_TKS] = g['spt']
    data[DD_FMT] = g['fmt']
    data[DD_SPT:DD_SPT+2] = g['spt'].to_bytes(2, 'big')
    path.write_bytes(data)
    print(f"Patched {profile} RBF geometry: {g['sectors']} logical sectors, {g['spt']} sectors/track")

if __name__ == '__main__':
    main()
