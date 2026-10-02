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

## Initial bring-up model

The first bring-up uses hardware task 0 for the system map and hardware
task 1 for the currently running user process.  NitrOS-9 may continue to
manage its normal software task/DAT images.  Use of the FM-11's additional
persistent hardware task maps is a later optimization.

`build-core.sh all` builds the 6809 and HD6309 bootstrap core.  This first
stage produces the IPL and fixed-layout kernel track, but does not yet
construct the complete OS9Boot/RBF 2D disk image.
