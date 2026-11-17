#!/usr/bin/env python3
"""Check FM-11 Level 2 RAM probe behavior under three absent-page models.

Source-level static assertions and a memory-decoder model only. This is
not an actual 6809 execution or a test of real FM-11 hardware.
"""
from pathlib import Path

source = (Path(__file__).resolve().parents[2] /
          "level2/modules/kernel/krn.asm").read_text()
start = source.index("                  IFNE    fm11\n* FM-11 hardware pages")
end = source.index("                  ELSE\n                  IFNE    H6309", start)
section = source[start:end]

for instruction in (
    "lda       #RAMinUse",
    "sta       ,x",
    "ldb       #$08",
    "lbsr      FM11Map5",
    "lda       >-$6000,x",
    "pshs      a",
    "lda       #$55",
    "cmpa      >-$6000,x",
    "cmpa      ,x",
    "lda       #$AA",
    "bne       FM11KrnProbeFail",
    "beq       FM11KrnProbeFail",
    "FM11KrnProbeFail",
    "FM11KrnSizeDone     stb       <D.MemSz",
):
    assert instruction in section, f"missing FM-11 RAM probe: {instruction}"
assert section.count("puls      a") == 4
assert section.count("sta       >-$6000,x") == 4
assert "cmpb      #$81" in section
assert section.count("sta       ,x") >= 3  # reserve block 0 + both restores


def simulate(kib, absent_mode):
    capacity = kib // 8   # physical blocks (8 KiB)
    ram = [(block * 19 + 5) & 255 for block in range(capacity)]
    ram[0] = 1             # explicitly reserve block zero
    original = ram[:]

    def mapped_block(block):
        # The MMR is 8 bit: block 128 maps to pages 0/1.
        block %= 128
        if block < capacity:
            return block
        if absent_mode == "mirror":
            return block % capacity
        return None

    def read(block):
        physical = mapped_block(block)
        if physical is None:
            return 0xFF if absent_mode == "ff" else 0
        return ram[physical]

    def write(block, value):
        physical = mapped_block(block)
        if physical is not None:
            ram[physical] = value

    detected = None
    for block in range(8, 129):
        saved_probe = read(block)
        saved_anchor = read(0)
        valid = True
        for value in (0x55, 0xAA):
            write(block, value)
            if read(block) != value or read(0) == value:
                valid = False
                break
        # Same order as the 6809 source: restore anchor first,
        # then the candidate (including if both addresses alias).
        write(0, saved_anchor)
        write(block, saved_probe)
        if not valid:
            detected = block
            break

    assert ram == original, f"{kib} KiB / {absent_mode}: RAM modified"
    return detected


for kib in range(128, 1025, 8):
    for mode in ("mirror", "ff", "zero"):
        blocks = simulate(kib, mode)
        assert blocks == kib // 8, (
            f"{kib} KiB / {mode}: detected {blocks} blocks "
            f"instead of {kib // 8}"
        )
print("PASS: FM-11 L2 113 capacities x mirror/FF/zero; dual readback, mirror check and restoration")
