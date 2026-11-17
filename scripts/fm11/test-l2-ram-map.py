#!/usr/bin/env python3
"""Regression for FM-11 Level 2's absent-RAM bitmap initialization.

The kernel's RAM probe returns installed 8 KiB blocks in B.  Before this
fix, B=$30 (384 KiB) underflowed during NotRAM marking and overwrote
system dispatch entries at $0300+.  This checks the FM-11-specific
assembly sequence and models its exact exclusive end-address bounds.

The model is a source-level regression, not an emulated 6809 execution.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = (root / "level2/modules/kernel/krn.asm").read_text()

start = source.index("                  IFNE    fm11\n* FM-11: B is the number")
end = source.index("                  ELSE\n                  IFNE    immunity", start)
fm11 = source[start:end]

required = (
    "cmpb      #$40",
    "bhs       FM11RAMMapDone",
    "abx",
    "lda       #NotRAM",
    "FM11MarkNotRAM      sta       ,x+",
    "incb",
    "blo       FM11MarkNotRAM",
    "FM11RAMMapDone      ldx       <D.BlkMap",
    "clrb",
)
for token in required:
    assert token in fm11, f"FM-11 RAM bitmap code missing {token!r}"

assert "subb      #$3F" not in fm11, "underflowing legacy count leaked into FM-11"
assert fm11.count("FM11MarkNotRAM") == 2


def mark_absent(ram_blocks):
    """Model the FM-11 assembly's X/B update and the marked byte offsets."""
    x = 0x0200
    b = ram_blocks
    marks = []
    if b < 0x40:
        x += b
        while True:
            marks.append(x)
            x += 1
            b += 1
            if b >= 0x40:
                break
    x = 0x0200  # ldx <D.BlkMap
    b = 0       # clrb
    return marks, x, b


for kib in range(128, 1025, 128):
    blocks = kib // 8
    marks, x, b = mark_absent(blocks)
    expected = list(range(0x0200 + blocks, 0x0240)) if blocks < 64 else []
    assert marks == expected, f"{kib} KiB: incorrect NotRAM blocks"
    assert all(0x0200 <= addr < 0x0240 for addr in marks)
    assert x == 0x0200 and b == 0, f"{kib} KiB: entry ABI broken"

# Key regression: 384 KiB must not reach $0300, where the service
# dispatch table begins; previous code marked through $031F.
marks, _, _ = mark_absent(48)
assert marks[0] == 0x0230 and marks[-1] == 0x023F
print("PASS: FM-11 L2 128..1024 KiB absent-RAM bitmap limits")
