********************************************************************
* mmu.asm - FM-11 Level 2 8 KiB DAT / 4 KiB MMR backend
*
* This file contains target-specific primitive mappings.  NitrOS-9 DAT
* images remain eight two-byte 8 KiB entries.  Hardware mappings expand
* one OS block P to FM-11 pages 2P and 2P+1.
*
* These routines are deliberately small and have explicit register ABIs
* so common kernel code can call them through thin FM-11 hooks.
********************************************************************

                    IFP1
                    use       defsfile
                    ENDC

                    org       0

********************************************************************
* Save/restore policy for temporary mappings.
*
* The FM-11 MMR registers are readable.  Do not assume that task 0 still
* has its boot-time identity mapping when a temporary map is removed.
* Each Map helper snapshots all four hardware MMR bytes covered by its
* matching Restore helper into fixed CPU-card SRAM before changing them.
*
* These save areas are one level deep per range.  A second Map01 before
* Restore01 (or Map56 before Restore56) replaces the previous snapshot.
********************************************************************

********************************************************************
* Map one 8 KiB OS block into logical block 0 ($0000-$1FFF).
*
* Entry: B = OS physical block number
* Exit : all registers preserved
********************************************************************
FM11MapBlock0       pshs      d,x,y
                    tfr       d,y
                    ldx       #FM11_MMR_BASE
                    lda       ,x
                    sta       >FM11_L2_MAPSAVE01
                    lda       1,x
                    sta       >FM11_L2_MAPSAVE01+1
                    lda       2,x
                    sta       >FM11_L2_MAPSAVE01+2
                    lda       3,x
                    sta       >FM11_L2_MAPSAVE01+3
                    tfr       y,d
                    tfr       b,a
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      d,x,y,pc

********************************************************************
* Map two 8 KiB OS blocks into logical blocks 0 and 1.
*
* Entry: A = first OS physical block
*        B = second OS physical block
* Exit : all registers preserved
********************************************************************
FM11MapBlocks01     pshs      d,x,y
                    tfr       d,y
                    ldx       #FM11_MMR_BASE
                    lda       ,x
                    sta       >FM11_L2_MAPSAVE01
                    lda       1,x
                    sta       >FM11_L2_MAPSAVE01+1
                    lda       2,x
                    sta       >FM11_L2_MAPSAVE01+2
                    lda       3,x
                    sta       >FM11_L2_MAPSAVE01+3
                    tfr       y,d
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x+
                    tfr       b,a
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      d,x,y,pc

********************************************************************
* Map one 8 KiB OS block into logical block 5 ($A000-$BFFF).
*
* Entry: B = OS physical block number
* Exit : all registers preserved
********************************************************************
FM11MapBlock5       pshs      d,x,y
                    tfr       d,y
                    ldx       #FM11_MMR_BASE+$0A
                    lda       ,x
                    sta       >FM11_L2_MAPSAVE56
                    lda       1,x
                    sta       >FM11_L2_MAPSAVE56+1
                    lda       2,x
                    sta       >FM11_L2_MAPSAVE56+2
                    lda       3,x
                    sta       >FM11_L2_MAPSAVE56+3
                    tfr       y,d
                    tfr       b,a
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      d,x,y,pc

********************************************************************
* Map source/destination blocks into logical blocks 5 and 6.
*
* Entry: A = source OS physical block -> $A000-$BFFF
*        B = destination OS physical block -> $C000-$DFFF
* Exit : all registers preserved
********************************************************************
FM11MapMove56       pshs      d,x,y
                    tfr       d,y
                    ldx       #FM11_MMR_BASE+$0A
                    lda       ,x
                    sta       >FM11_L2_MAPSAVE56
                    lda       1,x
                    sta       >FM11_L2_MAPSAVE56+1
                    lda       2,x
                    sta       >FM11_L2_MAPSAVE56+2
                    lda       3,x
                    sta       >FM11_L2_MAPSAVE56+3
                    tfr       y,d
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x+
                    tfr       b,a
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      d,x,y,pc

********************************************************************
* Restore the exact hardware mappings saved by the matching Map helper.
********************************************************************
FM11Restore01       pshs      a,x
                    ldx       #FM11_MMR_BASE
                    lda       >FM11_L2_MAPSAVE01
                    sta       ,x
                    lda       >FM11_L2_MAPSAVE01+1
                    sta       1,x
                    lda       >FM11_L2_MAPSAVE01+2
                    sta       2,x
                    lda       >FM11_L2_MAPSAVE01+3
                    sta       3,x
                    puls      a,x,pc

FM11Restore56       pshs      a,x
                    ldx       #FM11_MMR_BASE+$0A
                    lda       >FM11_L2_MAPSAVE56
                    sta       ,x
                    lda       >FM11_L2_MAPSAVE56+1
                    sta       1,x
                    lda       >FM11_L2_MAPSAVE56+2
                    sta       2,x
                    lda       >FM11_L2_MAPSAVE56+3
                    sta       3,x
                    puls      a,x,pc

********************************************************************
* Load a process DAT image through the fixed-RAM loader.
*
* Entry: B = hardware task number
*        U = NitrOS-9 8-entry DAT image
*
* The fixed loader stages all page pairs before selecting the destination
* task, so it remains safe when U points into task-0 memory.
********************************************************************
FM11LoadTask        jmp       >FM11_L2_SETTASK

                    end
