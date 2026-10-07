********************************************************************
* mmu.asm - FM-11 Level 2 MMR primitives
*
* Central FM-11 MMR primitive layer used by the Level 2 runtime.
*
* NitrOS-9 keeps the normal Level 2 8 KiB DAT abstraction.  One logical
* block P is expanded to the two FM-11 4 KiB hardware pages 2P and 2P+1.
*
* Interrupt masking remains the caller's responsibility.
*
* Temporary mappings snapshot the actual MMR10-MMR13 hardware contents
* before replacing logical blocks 5/6.  Restore operations therefore put
* back the exact mapping that was active before the transaction instead of
* assuming that D.SysDAT still describes the hardware state.
*
* The snapshot is one level deep.  Map5 starts a temporary transaction;
* Map6 extends that transaction and deliberately does not take a second
* snapshot.  FM11_MAP56_AB performs both operations as one transaction.
*
* F$Move cannot call a mapping subroutine after replacing logical blocks 5/6:
* its stack can itself live in one of those windows.  The no-stack mappings
* are therefore macros defined here and expanded inline by F$Move.  Other
* kernel users call the small routines below.
********************************************************************

                    ifndef    FM11_MMU_ROUTINES
FM11_MMU_ROUTINES   set       0
                    endc

********************************************************************
* Inline primitives.  These emit no stack accesses.
********************************************************************

* Raw mapping primitives.  They do not change the saved restore image.
FM11_MAP5_RAW_A     macro     noexpand
                    lsla
                    sta       >DAT.Regs+$0A
                    inca
                    sta       >DAT.Regs+$0B
                    endm

FM11_MAP6_RAW_A     macro     noexpand
                    lsla
                    sta       >DAT.Regs+$0C
                    inca
                    sta       >DAT.Regs+$0D
                    endm

* Save the complete 5/6 temporary-window mapping.  D is preserved through
* fixed CPU-card SRAM so this macro remains safe in F$Move's no-stack region.
FM11_SAVE56         macro     noexpand
                    std       >FM11_L2_MAPTMP
                    lda       >DAT.Regs+$0A
                    sta       >FM11_L2_MAPSAVE56
                    lda       >DAT.Regs+$0B
                    sta       >FM11_L2_MAPSAVE56+1
                    lda       >DAT.Regs+$0C
                    sta       >FM11_L2_MAPSAVE56+2
                    lda       >DAT.Regs+$0D
                    sta       >FM11_L2_MAPSAVE56+3
                    ldd       >FM11_L2_MAPTMP
                    endm

* Map5 starts a temporary mapping transaction and snapshots MMR10-MMR13.
FM11_MAP5_A         macro     noexpand
                    FM11_SAVE56
                    FM11_MAP5_RAW_A
                    endm

* Map6 extends a transaction already started by Map5.  It must not overwrite
* the saved pre-transaction mapping.
FM11_MAP6_A         macro     noexpand
                    FM11_MAP6_RAW_A
                    endm

* Atomic two-window transaction used by F$Move.
FM11_MAP56_AB       macro     noexpand
                    FM11_SAVE56
                    FM11_MAP5_RAW_A
                    tfr       b,a
                    FM11_MAP6_RAW_A
                    endm

* Restore the exact MMR10-MMR13 values saved at transaction entry.
* The historical _Y/_X names are retained so existing runtime call sites do
* not need to change; neither macro now consumes its named scratch register.
FM11_RESTORE56_Y    macro     noexpand
                    lda       >FM11_L2_MAPSAVE56
                    sta       >DAT.Regs+$0A
                    lda       >FM11_L2_MAPSAVE56+1
                    sta       >DAT.Regs+$0B
                    lda       >FM11_L2_MAPSAVE56+2
                    sta       >DAT.Regs+$0C
                    lda       >FM11_L2_MAPSAVE56+3
                    sta       >DAT.Regs+$0D
                    endm

FM11_RESTORE56_X    macro     noexpand
                    lda       >FM11_L2_MAPSAVE56
                    sta       >DAT.Regs+$0A
                    lda       >FM11_L2_MAPSAVE56+1
                    sta       >DAT.Regs+$0B
                    lda       >FM11_L2_MAPSAVE56+2
                    sta       >DAT.Regs+$0C
                    lda       >FM11_L2_MAPSAVE56+3
                    sta       >DAT.Regs+$0D
                    endm

* Fixed-RAM task loader.  Kept as a macro so the runtime has one canonical
* spelling without adding an otherwise unnecessary trampoline wrapper.
FM11_LOAD_TASK      macro     noexpand
                    jsr       >FM11_L2_SETTASK
                    endm

                  IFNE      FM11_MMU_ROUTINES

********************************************************************
* Map one 8 KiB OS physical block into logical block 5 ($A000-$BFFF).
*
* This starts a temporary mapping transaction by saving the actual hardware
* MMR10-MMR13 values, then replaces MMR10/MMR11.
*
* Entry: A = OS physical block number
* Exit : A = second FM-11 4 KiB page number (2*block+1)
*        all other registers preserved
********************************************************************
FM11Map5            FM11_MAP5_A
                    rts

********************************************************************
* Map one 8 KiB OS physical block into logical block 6 ($C000-$DFFF).
*
* This extends a transaction already started by FM11Map5; it intentionally
* does not snapshot MMRs again.
*
* Entry: A = OS physical block number
* Exit : A = second FM-11 4 KiB page number (2*block+1)
*        all other registers preserved
********************************************************************
FM11Map6            FM11_MAP6_A
                    rts

********************************************************************
* Restore logical block 5 to the exact hardware mapping saved by FM11Map5.
*
* Entry: none
* Exit : A destroyed
********************************************************************
FM11Restore5        lda       >FM11_L2_MAPSAVE56
                    sta       >DAT.Regs+$0A
                    lda       >FM11_L2_MAPSAVE56+1
                    sta       >DAT.Regs+$0B
                    rts

********************************************************************
* Restore logical blocks 5 and 6 to the exact hardware mapping saved at
* transaction entry.
*
* Entry: none
* Exit : A destroyed
********************************************************************
FM11Restore56       lda       >FM11_L2_MAPSAVE56
                    sta       >DAT.Regs+$0A
                    lda       >FM11_L2_MAPSAVE56+1
                    sta       >DAT.Regs+$0B
                    lda       >FM11_L2_MAPSAVE56+2
                    sta       >DAT.Regs+$0C
                    lda       >FM11_L2_MAPSAVE56+3
                    sta       >DAT.Regs+$0D
                    rts

********************************************************************
* Expand a complete NitrOS-9 DAT image into FM-11 MMR registers.
*
* Extracted from KrnActualMMUBlock in krn.asm.
*
* Entry: X = address of first FM-11 MMR register to update
*        U = address of eight-entry NitrOS-9 DAT image
* Exit : X advanced by 16 bytes
*        U advanced by 16 bytes
*        A/B destroyed
*
* DAT image entries are two bytes; the physical block number is byte +1.
********************************************************************
FM11MapDAT
                    ldb       #DAT.BlCt
FM11MapDATLoop      lda       ,u
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x+
                    leau      2,u
                    decb
                    bne       FM11MapDATLoop
                    rts

                  ENDC
