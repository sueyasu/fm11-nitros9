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

FM11_MAP5_A         macro     noexpand
                    lsla
                    sta       >DAT.Regs+$0A
                    inca
                    sta       >DAT.Regs+$0B
                    endm

FM11_MAP6_A         macro     noexpand
                    lsla
                    sta       >DAT.Regs+$0C
                    inca
                    sta       >DAT.Regs+$0D
                    endm

FM11_MAP56_AB       macro     noexpand
                    FM11_MAP5_A
                    tfr       b,a
                    FM11_MAP6_A
                    endm

* Restore logical blocks 5/6 from the system DAT image using Y as scratch.
* This is the form used by F$Move, where X/U are the live source/destination
* pointers throughout the no-stack interval.
FM11_RESTORE56_Y    macro     noexpand
                    ldy       <D.SysDAT
                    lda       $0B,y
                    FM11_MAP5_A
                    lda       $0D,y
                    FM11_MAP6_A
                    endm

* Same restore operation for code paths where X is already scratch.
FM11_RESTORE56_X    macro     noexpand
                    ldx       <D.SysDAT
                    lda       $0B,x
                    FM11_MAP5_A
                    lda       $0D,x
                    FM11_MAP6_A
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
* Extracted from FM11Map5 in fldabx.asm and equivalent inline sequences.
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
* Entry: A = OS physical block number
* Exit : A = second FM-11 4 KiB page number (2*block+1)
*        all other registers preserved
********************************************************************
FM11Map6            FM11_MAP6_A
                    rts

********************************************************************
* Restore logical block 5 from the system DAT image.
*
* This mirrors the current runtime policy in fldabx.asm.  It does NOT restore
* an arbitrary pre-map MMR snapshot; it restores the system mapping recorded
* in D.SysDAT.
*
* Entry: none
* Exit : A and U destroyed
********************************************************************
FM11Restore5        ldu       <D.SysDAT
                    lda       $0B,u
                    bra       FM11Map5

********************************************************************
* Restore logical blocks 5 and 6 from the system DAT image.
*
* This mirrors fldabx.asm, fld.asm, fmove.asm and krn.asm runtime behaviour.
*
* Entry: none
* Exit : A and U destroyed
********************************************************************
FM11Restore56       ldu       <D.SysDAT
                    lda       $0B,u
                    bsr       FM11Map5
                    lda       $0D,u
                    bra       FM11Map6

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
