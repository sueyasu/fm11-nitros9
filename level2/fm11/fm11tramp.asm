********************************************************************
* fm11tramp - FM-11 Level 2 fixed-RAM interrupt/SWI front end
*
* CPU-card SRAM at $FE00-$FFEF remains visible independently of the MMR.
* DAT images are standard eight-entry 8 KiB NitrOS-9 images; the fixed
* task loader expands each block P to hardware pages 2P and 2P+1.
********************************************************************

                    ifndef    FM11_TRAMP_EMBED
FM11_TRAMP_EMBED    set       0
                    endc

                  IFEQ      FM11_TRAMP_EMBED
                    nam       fm11tramp
                    ttl       FM-11 Level 2 fixed vector trampoline
                    IFP1
                    use       defsfile
                    ENDC
                    org       FM11_L2_TRAMP
                  ENDC

FM11TrImageStart    equ       *

FM11TrSWI3
                    orcc      #IntMasks
                    lda       #D.SWI3
                    bra       FM11TrSWICommon
                    fill      $00,(FM11_L2_SWI2-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrSWI2
                    orcc      #IntMasks
                    lda       #D.SWI2
                    bra       FM11TrSWICommon
                    fill      $00,(FM11_L2_FIRQ-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrFIRQ
                    lda       #D.FIRQ
                    bra       FM11TrTrapCommon
                    fill      $00,(FM11_L2_IRQ-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrIRQ
                    orcc      #IntMasks
                    lda       #D.IRQ
                    bra       FM11TrTrapCommon
                    fill      $00,(FM11_L2_SWI-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrSWI
                    lda       #D.SWI
                    bra       FM11TrSWICommon
                    fill      $00,(FM11_L2_NMI-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrNMI
                    lda       #D.NMI
                    bra       FM11TrTrapCommon

FM11TrSWICommon
                    sta       >FM11_L2_STATE+1
                    ldb       [R$PC,s]
                    stb       >FM11_L2_STATE+2
* $FD90 is readable; use the hardware selector as the current-task truth.
                    lda       >DAT.Task
                    beq       FM11TrSystemSWI

                    sts       >FM11_L2_USERS
                    tfr       s,u
                    ldy       #FM11_L2_SWISTACK
                    lda       #R$Size/2
FM11TrCopy          ldx       ,u++
                    stx       ,y++
                    deca
                    bne       FM11TrCopy
                    lds       #FM11_L2_SWISTACK

                    lda       #1
                    sta       >FM11_L2_STATE+3
                    bra       FM11TrSelectSystem

FM11TrSystemSWI
                    clra
                    tfr       a,dp
                    ldb       >FM11_L2_STATE+1
                    tfr       d,x
                    ldb       >FM11_L2_STATE+2
                    jmp       [,x]

FM11TrTrapCommon
                    sta       >FM11_L2_STATE+1
                    clra
                    sta       >FM11_L2_STATE+3
                    lda       >DAT.Task
                    beq       FM11TrSelectSystem

* A user interrupt frame becomes inaccessible after selecting task 0.
* Save the original virtual S and copy the frame to fixed SRAM first.
                    sts       >FM11_L2_USERS
                    tfr       s,u
                    ldy       #FM11_L2_SWISTACK
                    ldb       #R$Size
                    lda       >FM11_L2_STATE+1
                    cmpa      #D.FIRQ
                    bne       FM11TrTrapCopy
                    ldb       #3
FM11TrTrapCopy      lda       ,u+
                    sta       ,y+
                    decb
                    bne       FM11TrTrapCopy
                    lds       #FM11_L2_SWISTACK

FM11TrSelectSystem
* Read the task number from hardware before selecting task 0.  $FD90 is the
* authoritative current-task state; FM11_L2_STATE is no longer mirrored.
                    ldb       >DAT.Task
                    clra
                    sta       >DAT.Task
                    tfr       a,dp
                    tstb
                    beq       FM11TrKeepTask
                    stb       <D.TINIT
FM11TrKeepTask
                    clra
                    ldb       >FM11_L2_STATE+1
                    tfr       d,x
                    lda       >FM11_L2_STATE+3
                    beq       FM11TrDispatch
                    ldb       >FM11_L2_STATE+2
FM11TrDispatch      jmp       [,x]

                    fill      $00,(FM11_L2_STATE-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrTask          fcb       0
FM11TrVector        fcb       0
FM11TrSvc           fcb       0
FM11TrKind          fcb       0
FM11TrTarget        fcb       0
FM11TrFlipCC        fcb       0

                    fill      $00,(FM11_L2_SWISTACK-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrSWIStack      fill      $00,R$Size

                    fill      $00,(FM11_L2_RETUSR-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrReturnUser
                    sta       >DAT.Task
                    leas      ,y
                    tstb
                    bne       FM11TrReturnRTI
                    ldu       #FM11_L2_SWISTACK
                    lda       #R$Size/2
FM11TrReturnCopy    ldx       ,u++
                    stx       ,y++
                    deca
                    bne       FM11TrReturnCopy
FM11TrReturnRTI     rti

                    fill      $00,(FM11_L2_JMPUSR-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrJumpUser
                    lds       >FM11_L2_USERS
                    stb       >DAT.Task
                    jmp       ,u

                    fill      $00,(FM11_L2_RTIUSR-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrRTIUser
                    sta       >DAT.Task
                    rti

                    fill      $00,(FM11_L2_RTIMASK-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrRTIMasked
                    sta       >DAT.Task
                    lda       ,s
                    ora       #IntMasks
                    sta       ,s
                    rti

********************************************************************
* Fixed-RAM task-bank loader.
*
* Entry: B = destination hardware task
*        U = eight-entry NitrOS-9 DAT image
********************************************************************

                    fill      $00,(FM11_L2_DATBUF-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrDATBuf        fill      $00,FM11_MMR_PAGES

                    fill      $00,(FM11_L2_SETTASK-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrSetTask
* Preserve the caller-visible register set.  The loader uses D/X/Y/U as
* scratch while task 1 is being programmed, but its callers retain them.
                    pshs      cc,d,x,y,u
                    orcc      #IntMasks
                    tfr       d,y

* Stage eight OS blocks as sixteen hardware pages before changing tasks.
                    ldx       #FM11_L2_DATBUF
                    ldb       #DAT.BlCt
FM11TrStageDAT      lda       1,u
                    lsla
                    sta       ,x+
                    inca
                    sta       ,x+
                    leau      2,u
                    decb
                    bne       FM11TrStageDAT

* Program the destination bank with address translation left enabled.  The
* fixed-RAM trampoline does not execute from, or access data through, the
* destination task's translated address space while its sixteen MMRs are
* being updated, so temporarily selecting a partially programmed task is
* safe.
*
* Y preserves the entry D value while the DAT image is expanded.  Recover
* destination task B from Y here, select that task, write all sixteen MMRs,
* then select task 0 again before restoring registers from the caller's
* stack.
                    tfr       y,d
                    ldx       #FM11_MMR_TASK
                    stb       ,x

* $FD80 is exactly sixteen bytes below $FD90.  After sixteen post-increment
* stores X again points at $FD90, which makes the restore sequence compact.
                    leax      -16,x
                    ldu       #FM11_L2_DATBUF
                    ldb       #FM11_MMR_PAGES
FM11TrWriteDAT      lda       ,u+
                    sta       ,x+
                    decb
                    bne       FM11TrWriteDAT

                    clra
                    sta       ,x
                    puls      cc,d,x,y,u,pc

                    fill      $00,(FM11_L2_FLIP0-FM11_L2_TRAMP)-(*-FM11TrImageStart)
FM11TrFlip0
                    sta       >FM11_L2_STATE+5
                    clra
                    sta       >DAT.Task
                    clr       <D.SSTskN
                    tfr       x,s
                    lda       >FM11_L2_STATE+5
                    tfr       a,cc
                    rts

                    fill      $00,(FM11_L2_TRAMP_END-FM11_L2_TRAMP)-(*-FM11TrImageStart)

                  IFEQ      FM11_TRAMP_EMBED
                    end
                  ENDC
