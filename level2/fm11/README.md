# NitrOS-9 Level 2 for Fujitsu FM-11

This directory contains the FM-11-specific NitrOS-9 Level 2 port.

## Porting policy

The FM-11 port follows these rules:

1. Keep upstream/common sources unchanged whenever practical.  Common
   changes should be limited to generic fixes suitable for upstream, or
   small hooks that are strictly required by the FM-11 port.
2. Put substantially modified target-specific sources under
   `level2/fm11/`.
3. Do not share Level 1 and Level 2 implementation sources merely because
   the hardware is the same.  Existing upstream shared sources are the
   exception.

## DAT/MMR model

NitrOS-9 continues to use the normal Level 2 8 KiB DAT abstraction:

- 8 logical DAT blocks in a 64 KiB process address space
- 8 KiB per DAT block
- 16-byte DAT images (8 two-byte entries)
- up to 128 physical 8 KiB blocks in 1 MiB

The FM-11 MMR operates on 4 KiB pages.  One NitrOS-9 physical block P is
therefore represented by the consecutive FM-11 hardware pages:

    2*P, 2*P+1

Likewise each logical 8 KiB block occupies two consecutive MMR slots:

    OS block 0 -> slots 0,1
    OS block 1 -> slots 2,3
    ...
    OS block 7 -> slots E,F

This keeps the normal Level 2 memory-allocation and module-management
semantics at 8 KiB granularity.  FM-11-specific code is responsible for
expanding DAT entries into MMR page pairs.

The CPU-card fixed area at $FC00-$FFFF is visible independently of the MMR.
The kernel image therefore remains below $FC00.  The partial visibility of
logical block 7 is an FM-11-specific constraint and is handled separately
from the 8 KiB DAT abstraction.

## Installed RAM detection (128 KiB to 1 MiB)

FM-11 Level 2 probes installed RAM by mapping each 8 KiB OS physical
block into the temporary MMR page pair. Each probe now performs a
**two-pattern write/readback check (55h and AAh)** and verifies that
neither write has changed the physical block-0 sentinel. A failed
readback **or** a detected alias terminates the RAM scan. Both the
candidate byte and the block-0 sentinel are saved and restored on
every attempt, including alias termination. Block 0 is reserved
explicitly rather than as a side effect of alias detection.

The emulator accepts 128, 256, 384, 512, 640, 768, 896, and 1024 KiB,
corresponding to 16..128 OS blocks. The 8 KiB probe also recognizes
intermediate installed sizes (such as 192 KiB) if the hardware makes
these physically contiguous and visible through the MMR.

**Hardware caveat:** Open bus memory returning fixed zero or FFh is now
rejected. Certain unusual decoders may still appear writable even
without actual RAM, so validation with real FM-11 expansion hardware
remains necessary.

The FM-11-specific section of `level2/modules/kernel/krn.asm` now
marks absent blocks only within the original 64-block bitmap area
(`D.BlkMap + installed_blocks` through `D.BlkMap + $3F`) when RAM is
smaller than 512 KiB.  It leaves the bitmap base register X and B=0
for subsequent kernel initialization.  This avoids the old CoCo
marking loop, whose 8-bit subtraction wrapped for 384 KiB and wrote
through the system service dispatch table at $0300.

Run the source-level range regression with:

```sh
python3 scripts/fm11/test-l2-ram-map.py
python3 scripts/fm11/test-l2-ram-probe.py
```

To confirm the actual guest behavior, rebuild a Level 2 image and boot
it with `[memory] ram_kib = 384` in the FM-11 emulator configuration.
Also check 128, 256, 512, 640, 768, 896 and 1024 KiB with `mfree`.
The test script is a model, not a substitute for guest execution.

## Initial bring-up model

The first bring-up uses hardware task 0 for the system map and hardware
task 1 for the currently running user process.  NitrOS-9 may continue to
manage its normal software task/DAT images.  Use of the FM-11's additional
persistent hardware task maps is a later optimization.

Build and image-generation scripts are kept under `scripts/fm11/`.

The normal entry point is:

    scripts/fm11/build-images.sh 2 6809

Internal Level 2 build helpers are under `scripts/fm11/helper/`.  For
example, `scripts/fm11/helper/l2-build-core.sh all` builds the 6809 and
HD6309 bootstrap cores without constructing complete floppy images.
