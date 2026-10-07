********************************************************************
* mmu.asm - FM-11 Level 2 MMR primitives
*
* This file collects the primitive FM-11 MMR operations that already exist
* in the current runtime paths.  It is intentionally not wired into Krn yet.
*
* NitrOS-9 keeps the normal Level 2 8 KiB DAT abstraction.  One logical
* block P is expanded to the two FM-11 4 KiB hardware pages 2P and 2P+1.
*
* IMPORTANT:
*   - These routines mirror current runtime behaviour; they do not change
*     mapping policy.
*   - Interrupt masking remains the caller's responsibility, as it is in the
*     current fld/fldabx/fmove/krn code.
*   - F$Move has a no-stack interval while logical blocks 5/6 are remapped.
*     Do not replace that inline sequence with BSR/LBSR calls until that
*     constraint is handled explicitly.
********************************************************************

                    IFP1
                    use       defsfile
                    ENDC

                    org       0

********************************************************************
* Map one 8 KiB OS physical block into logical block 5 ($A000-$BFFF).
*
* Extracted from FM11Map5 in fldabx.asm and equivalent inline sequences.
*
* Entry: A = OS physical block number
* Exit : A = second FM-11 4 KiB page number (2*block+1)
*        all other registers preserved
********************************************************************
FM11Map5            lsla
                    sta       >DAT.Regs+$0A
                    inca
                    sta       >DAT.Regs+$0B
                    rts

********************************************************************
* Map one 8 KiB OS physical block into logical block 6 ($C000-$DFFF).
*
* Entry: A = OS physical block number
* Exit : A = second FM-11 4 KiB page number (2*block+1)
*        all other registers preserved
********************************************************************
FM11Map6            lsla
                    sta       >DAT.Regs+$0C
                    inca
                    sta       >DAT.Regs+$0D
                    rts

********************************************************************
* Map two 8 KiB blocks into logical blocks 5 and 6.
*
* This is the primitive operation performed inline by F$Move and by the
* register-stack copy paths in krn.asm.
*
* Entry: A = block for logical block 5 ($A000-$BFFF)
*        B = block for logical block 6 ($C000-$DFFF)
* Exit : A = second 4 KiB page of the block supplied in B
*        B preserved
*
* NOTE: The routine itself ends in RTS and therefore uses S.  Current F$Move
* deliberately performs this mapping inline because its stack may lie in a
* window being replaced.  This routine is for callers whose stack is known
* to remain accessible; F$Move must not call it as-is.
********************************************************************
FM11Map56           lsla
                    sta       >DAT.Regs+$0A
                    inca
                    sta       >DAT.Regs+$0B
                    tfr       b,a
                    lsla
                    sta       >DAT.Regs+$0C
                    inca
                    sta       >DAT.Regs+$0D
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
FM11MapDAT          leau      1,u
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

********************************************************************
* Load a software DAT image into an FM-11 hardware task bank.
*
* Runtime implementation remains in fixed CPU-card SRAM because programming
* an inactive task safely requires staging the DAT image and temporarily
* disabling translation.  This entry simply exposes that existing primitive.
*
* Entry: B = destination hardware task number
*        U = eight-entry NitrOS-9 DAT image
* Exit : caller-visible CC,D,X,Y,U preserved by the trampoline loader
********************************************************************
FM11LoadTask        jmp       >FM11_L2_SETTASK

                    end
