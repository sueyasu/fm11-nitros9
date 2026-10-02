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
* Map one 8 KiB OS block into logical block 0 ($0000-$1FFF).
*
* Entry: B = OS physical block number
* Exit : all registers preserved
********************************************************************
FM11MapBlock0       pshs      a,x
                    tfr       b,a
                    lsla
                    ldx       #FM11_MMR_BASE
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      a,x,pc

********************************************************************
* Map two 8 KiB OS blocks into logical blocks 0 and 1.
*
* Entry: A = first OS physical block
*        B = second OS physical block
* Exit : all registers preserved
********************************************************************
FM11MapBlocks01     pshs      d,x
                    ldx       #FM11_MMR_BASE
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x+
                    tfr       b,a
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      d,x,pc

********************************************************************
* Map one 8 KiB OS block into logical block 5 ($A000-$BFFF).
*
* Entry: B = OS physical block number
* Exit : all registers preserved
********************************************************************
FM11MapBlock5       pshs      a,x
                    tfr       b,a
                    lsla
                    ldx       #FM11_MMR_BASE+$0A
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      a,x,pc

********************************************************************
* Map source/destination blocks into logical blocks 5 and 6.
*
* Entry: A = source OS physical block -> $A000-$BFFF
*        B = destination OS physical block -> $C000-$DFFF
* Exit : all registers preserved
********************************************************************
FM11MapMove56       pshs      d,x
                    ldx       #FM11_MMR_BASE+$0A
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x+
                    tfr       b,a
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x
                    puls      d,x,pc

********************************************************************
* Restore task-0 identity mappings for logical blocks 0/1 or 5/6.
********************************************************************
FM11Restore01       pshs      d,x
                    ldx       #FM11_MMR_BASE
                    ldd       #$0001
                    std       ,x++
                    ldd       #$0203
                    std       ,x
                    puls      d,x,pc

FM11Restore56       pshs      d,x
                    ldx       #FM11_MMR_BASE+$0A
                    ldd       #$0A0B
                    std       ,x++
                    ldd       #$0C0D
                    std       ,x
                    puls      d,x,pc

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
