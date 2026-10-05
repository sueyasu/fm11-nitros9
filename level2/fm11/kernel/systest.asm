********************************************************************
* FM-11 staged boot test #6: launch the real Shell.
*
* Mirrors the normal KrnP2 order through standard-path setup, then:
*   5. F$Fork Shell
*   6. F$NProc to schedule the Shell
*
* Diagnostics:
*   SHELL START        = immediately before F$Fork
*   SHELL FORK OK P=xx = child descriptor built and queued
* After F$NProc, successful execution is confirmed by Shell's own output.
********************************************************************
FM11IOManTest       lbsr      LnkIOMan
                    bcc       FM11IOManLinked
                    leax      >FM11STFailIOManLink,pcr
                    lbra      FM11STFail

FM11IOManLinked     leax      >FM11STMsgIOManLink,pcr
                    lbsr      FM11STPutS
                    jsr       ,y
                    leax      >FM11STMsgIOManInit,pcr
                    lbsr      FM11STPutS

                    ldu       <D.Init
                    ldd       SysStr,u
                    bne       FM11STDDNameOK
                    clrb
                    leax      >FM11STFailDDSysStr,pcr
                    lbra      FM11STFail

FM11STDDNameOK      leax      d,u
                    lda       #(EXEC.+READ.)
                    os9       I$ChgDir
                    bcc       FM11STDDOK
                    leax      >FM11STFailDDChgDir,pcr
                    lbra      FM11STFail

FM11STDDOK          leax      >FM11STMsgDDChgDir,pcr
                    lbsr      FM11STPutS

                    ldu       <D.Init
                    ldd       <StdStr,u
                    bne       FM11STTermNameOK
                    clrb
                    leax      >FM11STFailTermStdStr,pcr
                    lbra      FM11STFail

FM11STTermNameOK    leax      d,u
                    lda       #UPDAT.
                    os9       I$Open
                    bcc       FM11STTermOK
                    leax      >FM11STFailTermOpen,pcr
                    lbra      FM11STFail

FM11STTermOK        ldx       <D.Proc
                    sta       <P$Path,x
                    pshs      a
                    leax      >FM11STMsgTermOpen,pcr
                    lbsr      FM11STPutS
                    puls      a

                    os9       I$Dup
                    bcc       FM11STDup1OK
                    leax      >FM11STFailTermDup1,pcr
                    lbra      FM11STFail
FM11STDup1OK        ldx       <D.Proc
                    sta       <P$Path+1,x

                    os9       I$Dup
                    bcc       FM11STDup2OK
                    leax      >FM11STFailTermDup2,pcr
                    lbra      FM11STFail
FM11STDup2OK        ldx       <D.Proc
                    sta       <P$Path+2,x

                    leax      >FM11STMsgStdPaths,pcr
                    lbsr      FM11STPutS

                    leax      >FM11STMsgShellStart,pcr
                    lbsr      FM11STPutS

                    leax      >FM11STShellName,pcr
                    lda       #Objct
                    clrb
                    ldy       #$0000
                    os9       F$Fork
                    bcc       FM11STShellForkOK
                    leax      >FM11STFailFork,pcr
                    lbra      FM11STFail

FM11STShellForkOK   pshs      a
                    leax      >FM11STMsgShellForkOK,pcr
                    lbsr      FM11STPutS
                    puls      a
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

                    os9       F$NProc

* F$NProc must transfer control to the scheduled Shell and not return here.
                    ldb       #$0A
                    leax      >FM11STFailNProcReturn,pcr
                    lbra      FM11STFail

********************************************************************
* FM11SysTest - minimal Level 2 system-call self-test
*
* Runs in KrnP2 system state.  It deliberately does not activate or
* schedule the process/task allocated by F$AllPrc/F$AllTsk.
********************************************************************

FM11SysTest
                    leax      >FM11STMsgStart,pcr
                    lbsr      FM11STPutS

* F$ID: simplest non-I/O service.
                    os9       F$ID
                    bcc       FM11STIDOK
                    leax      >FM11STFailID,pcr
                    lbra      FM11STFail
FM11STIDOK          leax      >FM11STMsgID,pcr
                    lbsr      FM11STPutS

* F$SRqMem: allocate one 256-byte system page.  Intentionally left
* allocated because this diagnostic halts immediately after the test.
                    ldd       #$0100
                    os9       F$SRqMem
                    bcc       FM11STMemOK
                    leax      >FM11STFailMem,pcr
                    lbra      FM11STFail
FM11STMemOK         leax      >FM11STMsgMem,pcr
                    lbsr      FM11STPutS

* F$AllPrc: allocate a process descriptor but do not activate it.
                    os9       F$AllPrc
                    bcc       FM11STPrcOK
                    leax      >FM11STFailPrc,pcr
                    lbra      FM11STFail
FM11STPrcOK         pshs      u
                    leax      >FM11STMsgPrc,pcr
                    lbsr      FM11STPutS
                    ldx       ,s
                    lda       P$ID,x
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

* F$AllTsk: assign/register a software task for the new descriptor.
* No F$AProc/F$NProc/F$Fork follows; the task is never executed.
                    ldx       ,s
                    os9       F$AllTsk
                    bcc       FM11STTskOK
                    leas      2,s
                    leax      >FM11STFailTsk,pcr
                    lbra      FM11STFail

FM11STTskOK         puls      x
                    pshs      x
                    leax      >FM11STMsgTsk,pcr
                    lbsr      FM11STPutS
                    ldx       ,s
                    lda       P$Task,x
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

* F$DelTsk: release the task again while leaving the process descriptor.
* Save the process ID for the following F$DelPrc test.
                    ldx       ,s
                    lda       P$ID,x
                    pshs      a
                    os9       F$DelTsk
                    bcc       FM11STDelTskOK
                    leas      3,s
                    leax      >FM11STFailDelTsk,pcr
                    lbra      FM11STFail

FM11STDelTskOK      leax      >FM11STMsgDelTsk,pcr
                    lbsr      FM11STPutS

* F$DelPrc: release the process descriptor.  Its task is already zero,
* so the internal F$DelTsk performed by F$DelPrc is a no-op.
                    puls      a
                    leas      2,s
                    os9       F$DelPrc
                    bcc       FM11STDelPrcOK
                    leax      >FM11STFailDelPrc,pcr
                    lbra      FM11STFail

FM11STDelPrcOK      leax      >FM11STMsgDelPrc,pcr
                    lbsr      FM11STPutS

* F$Link: link the resident Shell module only.  Do not execute it and do
* not call F$UnLink yet; this stage isolates F$Link itself.
                    leax      >FM11STShellName,pcr
                    lda       #Objct
                    os9       F$Link
                    bcc       FM11STLinkOK
                    leax      >FM11STFailLink,pcr
                    lbra      FM11STFail

FM11STLinkOK        leax      >FM11STMsgLink,pcr
                    lbsr      FM11STPutS

* F$SLink: repeat the lookup through the system-state link service.
* Do not execute or unlink the module yet; this stage isolates F$SLink.
                    leax      >FM11STShellName,pcr
                    ldy       <D.SysDAT
                    lda       #Objct
                    os9       F$SLink
                    bcc       FM11STSLinkOK
                    leax      >FM11STFailSLink,pcr
                    lbra      FM11STFail

FM11STSLinkOK       leax      >FM11STMsgSLink,pcr
                    lbsr      FM11STPutS

********************************************************************
* Expanded process-descriptor initialization test.
*
* Model the state built by F$Fork before F$AProc:
*   - allocate descriptor
*   - inherit user ID and priority
*   - install a known stack pointer and DAT image
*   - allocate/register the software task
*   - set parent ID and change to user state
*
* The process is never inserted into the active queue.
********************************************************************
                    os9       F$AllPrc
                    lbcs      FM11STPrcInitAllPrcFail
                    pshs      u

* Inherit user ID and priority from the current (system) process.
                    ldx       <D.Proc
                    ldd       P$User,x
                    std       P$User,u
                    lda       P$Prior,x
                    sta       P$Prior,u

* Give the descriptor a known logical user stack pointer.  It is not
* executed in this test.
                    ldd       #$2000-R$Size
                    std       P$SP,u

* Use the current system DAT image as a completely defined test image.
* This is only for registration/descriptor validation; no task switch is
* performed.
                    ldx       <D.SysDAT
                    leay      P$DATImg,u
                    ldb       #DAT.ImSz
FM11STPrcInitDATCopy
                    lda       ,x+
                    sta       ,y+
                    decb
                    bne       FM11STPrcInitDATCopy

* Register the descriptor as a software task.
                    ldx       ,s
                    os9       F$AllTsk
                    lbcs      FM11STPrcInitAllTskFail

* AllPrc creates the descriptor in system state.  AllTsk must not have
* changed that state apart from clearing ImgChg.
                    ldx       ,s
                    lda       P$State,x
                    cmpa      #SysState
                    lbne      FM11STPrcInitFailState

* Verify inherited user ID and priority.
                    ldy       <D.Proc
                    ldd       P$User,x
                    cmpd      P$User,y
                    lbne      FM11STPrcInitFailUser
                    lda       P$Prior,x
                    cmpa      P$Prior,y
                    lbne      FM11STPrcInitFailPrior

* Verify the known logical stack pointer.
                    ldd       P$SP,x
                    cmpd      #$2000-R$Size
                    lbne      FM11STPrcInitFailSP

* Verify that a real software task was assigned.
                    ldb       P$Task,x
                    lbeq      FM11STPrcInitFailTask

* D.TskIPt[task] must point to this descriptor's P$DATImg.
                    lslb
                    ldy       <D.TskIPt
                    ldy       b,y
                    leau      P$DATImg,x
                    pshs      y
                    cmpu      ,s++
                    lbne      FM11STPrcInitFailTskIPt

* Verify that the entire DAT image survived F$AllTsk unchanged.
                    ldy       <D.SysDAT
                    leau      P$DATImg,x
                    ldb       #DAT.ImSz
FM11STPrcInitDATCmp
                    lda       ,u+
                    cmpa      ,y+
                    lbne      FM11STPrcInitFailDAT
                    decb
                    bne       FM11STPrcInitDATCmp

* Finish the descriptor state exactly as F$Fork does immediately before
* F$AProc: establish the parent ID and switch the child out of SysState.
                    ldy       <D.Proc
                    lda       P$ID,y
                    sta       P$PID,x
                    lda       P$State,x
                    anda      #^SysState
                    sta       P$State,x

                    lda       P$PID,x
                    cmpa      P$ID,y
                    lbne      FM11STPrcInitFailPID
                    lda       P$State,x
                    lbne      FM11STPrcInitFailUserState

* Report the process and task numbers.
                    leax      >FM11STMsgPrcInit,pcr
                    lbsr      FM11STPutS
                    ldx       ,s
                    lda       P$ID,x
                    lbsr      FM11STHexA
                    leax      >FM11STMsgPrcInitTask,pcr
                    lbsr      FM11STPutS
                    ldx       ,s
                    lda       P$Task,x
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

* F$AProc single-service test.  At this early boot point the active queue
* must still be empty; require that so insertion and removal are unambiguous.
                    ldd       <D.AProcQ
                    lbne      FM11STAProcFailPreQueue

                    ldx       ,s
                    os9       F$AProc

* With an initially empty queue, the new descriptor must be the head,
* its next pointer must be zero, and F$AProc must copy priority to age.
                    ldx       ,s
                    cmpx      <D.AProcQ
                    lbne      FM11STAProcFailHead
                    ldd       P$Queue,x
                    lbne      FM11STAProcFailNext
                    lda       P$Age,x
                    cmpa      P$Prior,x
                    lbne      FM11STAProcFailAge

                    leax      >FM11STMsgAProc,pcr
                    lbsr      FM11STPutS
                    ldx       ,s
                    lda       P$ID,x
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

* Remove the test process from the active queue without scheduling it.
* The queue was required to be empty before insertion, so restoring the
* head to zero exactly restores its original state.
                    pshs      cc
                    orcc      #IntMasks
                    ldx       1,s
                    clra
                    clrb
                    std       <D.AProcQ
                    std       P$Queue,x
                    puls      cc

* Now the descriptor is no longer queued and can be deleted safely.
* F$DelPrc also releases its still-assigned task.
                    ldx       ,s
                    lda       P$ID,x
                    leas      2,s
                    os9       F$DelPrc
                    lbcs      FM11STPrcInitDelPrcFail

                    leax      >FM11STMsgAProcDel,pcr
                    lbsr      FM11STPutS

********************************************************************
* F$NProc single-service test.
*
* Build a second child descriptor and place it on the active queue.
* The child remains in SysState and its local descriptor stack contains
* a synthetic full RTI frame. F$NProc must consume that frame.
********************************************************************
                    os9       F$AllPrc
                    lbcs      FM11STNProcAllPrcFail
                    pshs      u

* Inherit priority from the current system process.
                    ldx       <D.Proc
                    lda       P$Prior,x
                    ldx       ,s
                    sta       P$Prior,x

* Allocate/register a software task before scheduling.
                    os9       F$AllTsk
                    lbcs      FM11STNProcAllTskFail

* Build a complete RTI frame at the top of the descriptor's local stack.
                    ldx       ,s
                    leau      >P$Stack-R$Size,x
                    stu       P$SP,x
                    leay      ,u
                    clra
                    ldb       #R$Size
FM11STNProcClrFrame
                    sta       ,y+
                    decb
                    bne       FM11STNProcClrFrame
                    lda       #Entire+IntMasks
                    sta       R$CC,u
                    leay      >FM11STNProcResume,pcr
                    sty       R$PC,u

* Explicitly keep this child in system state for the first NProc test.
                    lda       P$State,x
                    ora       #SysState
                    sta       P$State,x

* The previous AProc test restored the active queue to empty.
                    ldd       <D.AProcQ
                    lbne      FM11STNProcFailPreQueue

                    os9       F$AProc

                    leax      >FM11STMsgNProcCall,pcr
                    lbsr      FM11STPutS
                    ldx       ,s
                    lda       P$ID,x
                    lbsr      FM11STHexA
                    leax      >FM11STMsgNProcTask,pcr
                    lbsr      FM11STPutS
                    ldx       ,s
                    lda       P$Task,x
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

* F$NProc does not return through this caller's SWI2 frame.
                    leas      2,s
                    os9       F$NProc

                    ldb       #$01
                    leax      >FM11STFailNProcReturn,pcr
                    lbra      FM11STFail

* Reached only through the synthetic RTI frame in P$SP.
FM11STNProcResume
                    ldx       <D.Proc
                    cmpx      <D.SysPrc
                    lbeq      FM11STNProcFailCurrent

                    ldd       <D.AProcQ
                    lbne      FM11STNProcFailQueue
                    ldd       P$Queue,x
                    lbne      FM11STNProcFailLink

                    ldb       <D.Slice
                    cmpb      <D.TSlice
                    lbne      FM11STNProcFailSlice

                    leax      >FM11STMsgNProcOK,pcr
                    lbsr      FM11STPutS
                    ldx       <D.Proc
                    lda       P$ID,x
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

* Save child PID, restore the real system process/stack, then delete child.
                    ldx       <D.Proc
                    lda       P$ID,x
                    ldu       <D.SysPrc
                    stu       <D.Proc
                    lds       <D.SysStk
                    os9       F$DelPrc
                    lbcs      FM11STNProcDelPrcFail

                    leax      >FM11STMsgNProcDel,pcr
                    lbsr      FM11STPutS

********************************************************************
* F$Fork single-service test.
*
* Fork the resident Shell module but do not schedule it.  This tests
* child construction and active-queue insertion only.
********************************************************************
                    ldd       <D.AProcQ
                    lbne      FM11STForkFailPreQueue

                    leax      >FM11STShellName,pcr
                    lda       #Objct
                    clrb
                    ldy       #$0000
                    os9       F$Fork
                    bcc       FM11STForkOK
                    leax      >FM11STFailFork,pcr
                    lbra      FM11STFail

FM11STForkOK        pshs      a

* The forked child must be the only active process.
                    ldx       <D.AProcQ
                    lbeq      FM11STForkFailQueue
                    cmpa      P$ID,x
                    lbne      FM11STForkFailPID
                    ldd       P$Queue,x
                    lbne      FM11STForkFailNext

* Verify parent/child linkage.
                    ldy       <D.SysPrc
                    lda       P$PID,x
                    cmpa      P$ID,y
                    lbne      FM11STForkFailParent
                    lda       P$CID,y
                    cmpa      P$ID,x
                    lbne      FM11STForkFailChild

* Child is ready for user-state scheduling.  F$Fork releases its temporary
* task before placing the child on the active queue.
                    lda       P$State,x
                    bita      #SysState
                    lbne      FM11STForkFailState
                    ldd       P$PModul,x
                    lbeq      FM11STForkFailModule
                    lda       P$Task,x
                    lbne      FM11STForkFailTask

                    leax      >FM11STMsgFork,pcr
                    lbsr      FM11STPutS
                    puls      a
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

********************************************************************
* User SWI2/F$Exit test.
*
* FM11Idle immediately executes F$Exit with B=$5A.  F$Wait blocks
* this parent until the child exits, then returns child PID in A and
* exit status in B.
********************************************************************
                    ldx       <D.AProcQ
                    lda       P$ID,x
                    pshs      a

                    leax      >FM11STMsgWaitCall,pcr
                    lbsr      FM11STPutS
                    lda       ,s
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF

                    os9       F$Wait
                    bcs       FM11STWaitFail

                    cmpa      ,s
                    bne       FM11STWaitPIDFail
                    cmpb      #$5A
                    bne       FM11STWaitStatusFail
                    leas      1,s

                    leax      >FM11STMsgWaitOK,pcr
                    lbsr      FM11STPutS
                    lbra      FM11STPrcInitDone

FM11STWaitFail
                    leas      1,s
                    leax      >FM11STFailWait,pcr
                    lbra      FM11STFail

FM11STWaitPIDFail
                    leas      1,s
                    ldb       #$01
                    leax      >FM11STFailWaitCheck,pcr
                    lbra      FM11STFail

FM11STWaitStatusFail
                    leas      1,s
                    ldb       #$02
                    leax      >FM11STFailWaitCheck,pcr
                    lbra      FM11STFail

FM11STForkFailPreQueue
                    ldb       #$01
                    bra       FM11STForkCheckFail
FM11STForkFailQueue
                    leas      1,s
                    ldb       #$02
                    bra       FM11STForkCheckFail
FM11STForkFailPID
                    leas      1,s
                    ldb       #$03
                    bra       FM11STForkCheckFail
FM11STForkFailNext
                    leas      1,s
                    ldb       #$04
                    bra       FM11STForkCheckFail
FM11STForkFailParent
                    leas      1,s
                    ldb       #$05
                    bra       FM11STForkCheckFail
FM11STForkFailChild
                    leas      1,s
                    ldb       #$06
                    bra       FM11STForkCheckFail
FM11STForkFailState
                    leas      1,s
                    ldb       #$07
                    bra       FM11STForkCheckFail
FM11STForkFailModule
                    leas      1,s
                    ldb       #$08
                    bra       FM11STForkCheckFail
FM11STForkFailTask
                    leas      1,s
                    ldb       #$09
FM11STForkCheckFail
                    leax      >FM11STFailForkCheck,pcr
                    lbra      FM11STFail

FM11STNProcAllPrcFail
                    leax      >FM11STFailNProcAllPrc,pcr
                    lbra      FM11STFail

FM11STNProcAllTskFail
                    leas      2,s
                    leax      >FM11STFailNProcAllTsk,pcr
                    lbra      FM11STFail

FM11STNProcDelPrcFail
                    leax      >FM11STFailNProcDelPrc,pcr
                    lbra      FM11STFail

FM11STNProcFailPreQueue
                    ldb       #$01
                    bra       FM11STNProcCheckFail
FM11STNProcFailCurrent
                    ldb       #$02
                    bra       FM11STNProcCheckFail
FM11STNProcFailQueue
                    ldb       #$03
                    bra       FM11STNProcCheckFail
FM11STNProcFailLink
                    ldb       #$04
                    bra       FM11STNProcCheckFail
FM11STNProcFailSlice
                    ldb       #$05
FM11STNProcCheckFail
                    leax      >FM11STFailNProcCheck,pcr
                    lbra      FM11STFail


FM11STPrcInitAllPrcFail
                    leax      >FM11STFailPrcInitAllPrc,pcr
                    lbra      FM11STFail

FM11STPrcInitAllTskFail
                    leas      2,s
                    leax      >FM11STFailPrcInitAllTsk,pcr
                    lbra      FM11STFail

FM11STPrcInitDelPrcFail
                    leax      >FM11STFailPrcInitDelPrc,pcr
                    lbra      FM11STFail

FM11STAProcFailPreQueue
                    ldb       #$01
                    bra       FM11STAProcCheckFail
FM11STAProcFailHead
                    ldb       #$02
                    bra       FM11STAProcCheckFail
FM11STAProcFailNext
                    ldb       #$03
                    bra       FM11STAProcCheckFail
FM11STAProcFailAge
                    ldb       #$04
FM11STAProcCheckFail
                    leas      2,s
                    leax      >FM11STFailAProcCheck,pcr
                    lbra      FM11STFail

* Internal consistency failures use a small check code rather than an
* OS-9 error number.
FM11STPrcInitFailState
                    ldb       #$01
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailUser
                    ldb       #$02
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailPrior
                    ldb       #$03
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailSP
                    ldb       #$04
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailTask
                    ldb       #$05
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailTskIPt
                    ldb       #$06
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailDAT
                    ldb       #$07
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailPID
                    ldb       #$08
                    bra       FM11STPrcInitCheckFail
FM11STPrcInitFailUserState
                    ldb       #$09
FM11STPrcInitCheckFail
                    leas      2,s
                    leax      >FM11STFailPrcInitCheck,pcr
                    lbra      FM11STFail

FM11STPrcInitDone
                    leax      >FM11STMsgDone,pcr
                    lbsr      FM11STPutS
FM11STDone          bra       FM11STDone

* X -> NUL terminated string.  Clobbers A/X.
FM11STPutS          lda       ,x+
                    beq       FM11STPutSRet
                    lbsr      FM11STPutC
                    bra       FM11STPutS
FM11STPutSRet       rts

* A = character.  Preserve character while polling the USART.
FM11STPutC          pshs      a
FM11STPutCWait      lda       >UART_CTRL
                    bita      #UART_TXRDY
                    beq       FM11STPutCWait
                    puls      a
                    sta       >UART_DATA
                    rts

FM11STCRLF          lda       #$0D
                    lbsr      FM11STPutC
                    lda       #$0A
                    lbra      FM11STPutC

* A = byte to print as two uppercase hex digits.
FM11STHexA          pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    lbsr      FM11STHexNib
                    puls      a
                    anda      #$0F
FM11STHexNib        adda      #'0
                    cmpa      #'9
                    bls       FM11STHexOut
                    adda      #7
FM11STHexOut        lbra      FM11STPutC

* X -> failure prefix, B = OS-9 error code.
FM11STFail          pshs      b
                    lbsr      FM11STPutS
                    puls      a
                    lbsr      FM11STHexA
                    lbsr      FM11STCRLF
FM11STFailStop      bra       FM11STFailStop

FM11STMsgStart      fcc       /SYSTEST START/
                    fcb       $0D,$0A,$00
FM11STMsgID         fcc       /ID OK/
                    fcb       $0D,$0A,$00
FM11STMsgMem        fcc       /SRQMEM OK/
                    fcb       $0D,$0A,$00
FM11STMsgPrc        fcc       /ALLPRC OK P=/
                    fcb       $00
FM11STMsgTsk        fcc       /ALLTSK OK T=/
                    fcb       $00
FM11STMsgDelTsk     fcc       /DELTSK OK/
                    fcb       $0D,$0A,$00
FM11STMsgDelPrc     fcc       /DELPRC OK/
                    fcb       $0D,$0A,$00
FM11STMsgLink       fcc       /LINK IDLE OK/
                    fcb       $0D,$0A,$00
FM11STMsgSLink      fcc       /SLINK IDLE OK/
                    fcb       $0D,$0A,$00
FM11STMsgPrcInit    fcc       /PRCINIT OK P=/
                    fcb       $00
FM11STMsgPrcInitTask fcc      / T=/
                    fcb       $00
FM11STMsgAProc      fcc       /APROC OK P=/
                    fcb       $00
FM11STMsgAProcDel   fcc       /APROC DEL OK/
                    fcb       $0D,$0A,$00
FM11STMsgNProcCall  fcc       /NPROC CALL P=/
                    fcb       $00
FM11STMsgNProcTask  fcc       / T=/
                    fcb       $00
FM11STMsgNProcOK    fcc       /NPROC OK P=/
                    fcb       $00
FM11STMsgNProcDel   fcc       /NPROC DEL OK/
                    fcb       $0D,$0A,$00
FM11STMsgFork       fcc       /FORK IDLE OK P=/
                    fcb       $00
FM11STMsgWaitCall   fcc       /WAIT IDLE CALL P=/
                    fcb       $00
FM11STMsgWaitOK     fcc       /USER SWI2 EXIT OK/
                    fcb       $0D,$0A,$00
FM11STMsgDone       fcc       /DONE/
                    fcb       $0D,$0A,$00
FM11STMsgIOManLink  fcc       /IOMAN LINK OK/
                    fcb       $0D,$0A,$00
FM11STMsgIOManInit  fcc       /IOMAN INIT OK/
                    fcb       $0D,$0A,$00
FM11STMsgDDChgDir   fcc       /DD CHGDIR OK/
                    fcb       $0D,$0A,$00
FM11STMsgTermOpen   fcc       /TERM OPEN OK/
                    fcb       $0D,$0A,$00
FM11STMsgStdPaths   fcc       /STD PATHS OK/
                    fcb       $0D,$0A,$00
FM11STMsgShellStart fcc       /SHELL START/
                    fcb       $0D,$0A,$00
FM11STMsgShellForkOK fcc      /SHELL FORK OK P=/
                    fcb       $00

FM11STShellName     fcs       /Shell/

FM11STFailID        fcc       /ID FAIL E=/
                    fcb       $00
FM11STFailMem       fcc       /SRQMEM FAIL E=/
                    fcb       $00
FM11STFailPrc       fcc       /ALLPRC FAIL E=/
                    fcb       $00
FM11STFailTsk       fcc       /ALLTSK FAIL E=/
                    fcb       $00
FM11STFailDelTsk    fcc       /DELTSK FAIL E=/
                    fcb       $00
FM11STFailDelPrc    fcc       /DELPRC FAIL E=/
                    fcb       $00
FM11STFailLink      fcc       /LINK IDLE FAIL E=/
                    fcb       $00
FM11STFailSLink     fcc       /SLINK IDLE FAIL E=/
                    fcb       $00
FM11STFailPrcInitAllPrc fcc   /PRCINIT ALLPRC FAIL E=/
                    fcb       $00
FM11STFailPrcInitAllTsk fcc   /PRCINIT ALLTSK FAIL E=/
                    fcb       $00
FM11STFailPrcInitDelPrc fcc   /PRCINIT DELPRC FAIL E=/
                    fcb       $00
FM11STFailPrcInitCheck fcc    /PRCINIT FAIL C=/
                    fcb       $00
FM11STFailAProcCheck fcc      /APROC FAIL C=/
                    fcb       $00
FM11STFailNProcAllPrc fcc     /NPROC ALLPRC FAIL E=/
                    fcb       $00
FM11STFailNProcAllTsk fcc     /NPROC ALLTSK FAIL E=/
                    fcb       $00
FM11STFailNProcDelPrc fcc     /NPROC DELPRC FAIL E=/
                    fcb       $00
FM11STFailNProcReturn fcc     /NPROC RETURN FAIL C=/
                    fcb       $00
FM11STFailNProcCheck fcc      /NPROC FAIL C=/
                    fcb       $00
FM11STFailFork      fcc       /FORK IDLE FAIL E=/
                    fcb       $00
FM11STFailForkCheck fcc       /FORK IDLE FAIL C=/
                    fcb       $00
FM11STFailWait      fcc       /WAIT IDLE FAIL E=/
                    fcb       $00
FM11STFailWaitCheck fcc       /WAIT IDLE FAIL C=/
                    fcb       $00
FM11STFailIOManLink fcc       /IOMAN LINK FAIL E=/
                    fcb       $00
FM11STFailDDSysStr  fcc       /DD SYSSTR FAIL E=/
                    fcb       $00
FM11STFailDDChgDir  fcc       /DD CHGDIR FAIL E=/
                    fcb       $00
FM11STFailTermStdStr fcc      /TERM STDSTR FAIL E=/
                    fcb       $00
FM11STFailTermOpen  fcc       /TERM OPEN FAIL E=/
                    fcb       $00
FM11STFailTermDup1  fcc       /TERM DUP1 FAIL E=/
                    fcb       $00
FM11STFailTermDup2  fcc       /TERM DUP2 FAIL E=/
                    fcb       $00
