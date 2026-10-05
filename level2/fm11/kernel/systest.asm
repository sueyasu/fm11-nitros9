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
FM11STMsgLink       fcc       /LINK SHELL OK/
                    fcb       $0D,$0A,$00
FM11STMsgSLink      fcc       /SLINK SHELL OK/
                    fcb       $0D,$0A,$00
FM11STMsgDone       fcc       /DONE/
                    fcb       $0D,$0A,$00

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
FM11STFailLink      fcc       /LINK SHELL FAIL E=/
                    fcb       $00
FM11STFailSLink     fcc       /SLINK SHELL FAIL E=/
                    fcb       $00
