********************************************************************
* MMUTest - FM-11 MMR/MMU Level 1 diagnostic
*
* This is the first-stage MMU test for the FM-11 Level 2 port.
* It deliberately tests only the currently selected MMR task bank;
* task switching is NOT tested here.
*
* Requirements / assumptions:
*   - Run under the FM-11 NitrOS-9 Level 1 v39 environment.
*   - MMR must be disabled on entry (FD93 bit 7 = 0).
*   - Physical 4K blocks $10 and $11 are scratch blocks.  This is
*     safe in fm11-headless, which provides 1 MiB RAM and Level 1
*     uses only the first 64 KiB.  Do not run this version on real
*     hardware until the installed extended RAM has been verified.
*
* Test sequence:
*   1. Choose a 4K-aligned logical page wholly inside this process'
*      private scratch area.  Pages 5, 7 and F are avoided because
*      FM-11 has special windows in those ranges.
*   2. Save current MMR registers for the current task.
*   3. Program an identity map 00..0F and verify read-back.
*   4. Enable MMR, map the logical test page to physical block $10,
*      fill all 4096 bytes with an incrementing pattern.
*   5. Map the same page to physical block $11 and fill all 4096
*      bytes with a decrementing pattern.
*   6. Remap to $10 and $11 and verify both pages independently.
*   7. Disable MMR, restore all saved MMR registers and CC.
*
* No OS-9 system call is made while MMR is enabled.
********************************************************************

                    nam       MMUTest
                    ttl       FM-11 MMR/MMU Level 1 diagnostic

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

FM11_MMR_BASE       equ       $FD80
FM11_MMR_TASK       equ       $FD90
FM11_MMR_ENABLE     equ       $80

PhysBlockA          equ       $10
PhysBlockB          equ       $11

* Status codes returned in Status:
*   0 = PASS
*   1 = MMR was already enabled on entry
*   2 = no safe logical test window found
*   3 = identity-map MMR read-back failed
*   4 = physical block A MMR read-back failed
*   5 = physical block B MMR read-back failed
*   6 = physical block A data verify failed
*   7 = physical block B data verify failed

                    mod       eom,name,tylg,atrv,start,size

                    org       0
Status              rmb       1
SavedCC             rmb       1
SavedTask           rmb       1
SavedCtl            rmb       1
WindowBlock         rmb       1
FailBlock           rmb       1
FailExpected        rmb       1
FailActual          rmb       1
WindowAddr          rmb       2
FailOffset          rmb       2
HexValue            rmb       2
HexBuf              rmb       4
SavedMMR            rmb       16
                    rmb       32

* Keep control variables below Scratch.  Scratch is deliberately 12 KiB,
* which guarantees at least two complete 4 KiB-aligned pages even when the
* process data base is only 256-byte aligned.  Therefore one special FM-11
* page can be skipped safely.
Scratch             rmb       $3000
ScratchEnd          equ       *

* F$Chain/F$Fork place the process stack near the upper end of the data area.
* Keep an explicit gap above Scratch so the selected MMR page can never hide
* the running stack.
StackReserve        rmb       $0200
size                equ       .

name                fcs       /MMUTest/
                    fcb       edition

start               clr       Status,u

                    leax      Header,pcr
                    ldy       #HeaderEnd-Header
                    lbsr      Put

                    lda       >FM11_ROMCTL
                    bita      #FM11_MMR_ENABLE
                    beq       FindWin
                    lda       #1
                    sta       Status,u
                    lbra      Report

FindWin             leax      Scratch,u
                    tfr       x,d
                    addd      #$0FFF
                    anda      #$F0
                    clrb

TryWin              tfr       a,b
                    lsrb
                    lsrb
                    lsrb
                    lsrb
                    cmpb      #$05                boot ROM window
                    beq       NextWin
                    cmpb      #$07                optional $7C00 window
                    beq       NextWin
                    cmpb      #$0F                $FC00-$FFFF is special
                    beq       NoWindow
                    stb       WindowBlock,u
                    clrb
                    std       WindowAddr,u
                    bra       ShowWindow

NextWin             clrb
                    addd      #$1000
                    bcs       NoWindow
                    bra       TryWin

NoWindow            lda       #2
                    sta       Status,u
                    lbra      Report

ShowWindow          leax      WindowMsg,pcr
                    ldy       #WindowMsgEnd-WindowMsg
                    lbsr      Put
                    ldd       WindowAddr,u
                    lbsr      PutHex16
                    leax      PhysMsg,pcr
                    ldy       #PhysMsgEnd-PhysMsg
                    lbsr      Put

                    lbsr      RunTest

Report              lda       Status,u
                    bne       Failed

                    leax      PassMsg,pcr
                    ldy       #PassMsgEnd-PassMsg
                    lbsr      Put
                    clrb
                    lbra      Exit

Failed              leax      FailMsg,pcr
                    ldy       #FailMsgEnd-FailMsg
                    lbsr      Put
                    lda       Status,u
                    lbsr      PutHex8

                    leax      CRLF,pcr
                    ldy       #CRLFEnd-CRLF
                    lbsr      Put

                    lda       Status,u
                    cmpa      #3
                    blo       FailText
                    cmpa      #5
                    bhi       FailData

* Status 3..5: show the MMR block involved in the read-back failure.
                    leax      BlockMsg,pcr
                    ldy       #BlockMsgEnd-BlockMsg
                    lbsr      Put
                    lda       FailBlock,u
                    lbsr      PutHex8
                    leax      CRLF,pcr
                    ldy       #CRLFEnd-CRLF
                    lbsr      Put
                    bra       FailText

FailData            cmpa      #6
                    blo       FailText
                    cmpa      #7
                    bhi       FailText
                    leax      OffsetMsg,pcr
                    ldy       #OffsetMsgEnd-OffsetMsg
                    lbsr      Put
                    ldd       FailOffset,u
                    lbsr      PutHex16
                    leax      ExpectedMsg,pcr
                    ldy       #ExpectedMsgEnd-ExpectedMsg
                    lbsr      Put
                    lda       FailExpected,u
                    lbsr      PutHex8
                    leax      ActualMsg,pcr
                    ldy       #ActualMsgEnd-ActualMsg
                    lbsr      Put
                    lda       FailActual,u
                    lbsr      PutHex8
                    leax      CRLF,pcr
                    ldy       #CRLFEnd-CRLF
                    lbsr      Put

FailText            leax      CodeMsg,pcr
                    ldy       #CodeMsgEnd-CodeMsg
                    lbsr      Put
                    clrb

Exit                os9       F$Exit

********************************************************************
* RunTest
*
* MMR is known to be disabled on entry.  This routine masks IRQ/FIRQ before
* touching the MMR configuration and restores all state before returning.
********************************************************************
RunTest             tfr       cc,a
                    sta       SavedCC,u
                    orcc      #IntMasks

                    lda       >FM11_MMR_TASK
                    anda      #$0F
                    sta       SavedTask,u
                    lda       >FM11_ROMCTL
                    sta       SavedCtl,u

* Save the currently selected task's 16 MMR registers.
                    ldx       #FM11_MMR_BASE
                    leay      SavedMMR,u
                    ldb       #16
SaveLoop            lda       ,x+
                    sta       ,y+
                    decb
                    bne       SaveLoop

* Program identity mapping and verify the newly implemented read-back path.
                    ldx       #FM11_MMR_BASE
                    clra
                    ldb       #16
IdentLoop           sta       ,x
                    cmpa      ,x
                    lbne      IdentFail
                    leax      1,x
                    inca
                    decb
                    bne       IdentLoop

* Enable the MMR while preserving all other FD93 control bits.
                    lda       SavedCtl,u
                    ora       #FM11_MMR_ENABLE
                    sta       >FM11_ROMCTL

* Map logical test page to physical block A and verify MMR read-back.
                    ldb       WindowBlock,u
                    ldx       #FM11_MMR_BASE
                    abx
                    lda       #PhysBlockA
                    sta       ,x
                    cmpa      ,x
                    lbne      MapAFail

* Fill physical block A with 00,01,...,FF repeated over the full 4 KiB.
                    ldx       WindowAddr,u
                    ldy       #$1000
                    clra
FillA               sta       ,x+
                    inca
                    leay      -1,y
                    bne       FillA

* Map to physical block B and verify MMR read-back.
                    ldb       WindowBlock,u
                    ldx       #FM11_MMR_BASE
                    abx
                    lda       #PhysBlockB
                    sta       ,x
                    cmpa      ,x
                    lbne      MapBFail

* Fill physical block B with FF,FE,...,00 repeated over the full 4 KiB.
                    ldx       WindowAddr,u
                    ldy       #$1000
                    lda       #$FF
FillB               sta       ,x+
                    deca
                    leay      -1,y
                    bne       FillB

* Return to physical block A and verify the first pattern survived.
                    ldb       WindowBlock,u
                    ldx       #FM11_MMR_BASE
                    abx
                    lda       #PhysBlockA
                    sta       ,x
                    cmpa      ,x
                    lbne      MapAFail

                    ldx       WindowAddr,u
                    ldy       #$1000
                    clra
VerifyA             cmpa      ,x
                    lbne      DataAFail
                    leax      1,x
                    inca
                    leay      -1,y
                    bne       VerifyA

* Return to physical block B and verify the second pattern survived.
                    ldb       WindowBlock,u
                    ldx       #FM11_MMR_BASE
                    abx
                    lda       #PhysBlockB
                    sta       ,x
                    cmpa      ,x
                    lbne      MapBFail

                    ldx       WindowAddr,u
                    ldy       #$1000
                    lda       #$FF
VerifyB             cmpa      ,x
                    lbne      DataBFail
                    leax      1,x
                    deca
                    leay      -1,y
                    bne       VerifyB

                    clr       Status,u
                    bra       Restore

IdentFail           sta       FailBlock,u
                    lda       #3
                    sta       Status,u
                    bra       Restore

MapAFail            lda       WindowBlock,u
                    sta       FailBlock,u
                    lda       #4
                    sta       Status,u
                    bra       Restore

MapBFail            lda       WindowBlock,u
                    sta       FailBlock,u
                    lda       #5
                    sta       Status,u
                    bra       Restore

DataAFail           sta       FailExpected,u
                    ldb       ,x
                    stb       FailActual,u
                    tfr       x,d
                    subd      WindowAddr,u
                    std       FailOffset,u
                    lda       #6
                    sta       Status,u
                    bra       Restore

DataBFail           sta       FailExpected,u
                    ldb       ,x
                    stb       FailActual,u
                    tfr       x,d
                    subd      WindowAddr,u
                    std       FailOffset,u
                    lda       #7
                    sta       Status,u

* IMPORTANT: disable MMR before restoring the saved registers.  The saved
* mappings need not be identity mappings, and restoring them while enabled
* could hide the currently executing code or stack.
Restore             lda       SavedCtl,u
                    anda      #$7F
                    sta       >FM11_ROMCTL

                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    leay      SavedMMR,u
                    ldb       #16
RestoreLoop         lda       ,y+
                    sta       ,x+
                    decb
                    bne       RestoreLoop

                    lda       SavedCtl,u
                    sta       >FM11_ROMCTL
                    lda       SavedCC,u
                    tfr       a,cc
                    rts

********************************************************************
* Put / hexadecimal output helpers.  These are used only with MMR disabled.
********************************************************************
Put                 lda       #1
                    os9       I$Write
                    lbcs      Exit
                    rts

PutHex16            std       HexValue,u
                    leax      HexBuf,u
                    lda       HexValue,u
                    bsr       StoreHexByte
                    lda       HexValue+1,u
                    bsr       StoreHexByte
                    leax      HexBuf,u
                    ldy       #4
                    bra       Put

PutHex8             leax      HexBuf,u
                    bsr       StoreHexByte
                    leax      HexBuf,u
                    ldy       #2
                    bra       Put

StoreHexByte        pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    anda      #$0F
                    bsr       Nibble
                    sta       ,x+
                    puls      a
                    anda      #$0F
                    bsr       Nibble
                    sta       ,x+
                    rts

Nibble              cmpa      #10
                    blo       Digit
                    adda      #$37                'A'-10
                    rts
Digit               adda      #$30                '0'
                    rts

Header              fcc       /FM-11 MMR test v1 (Level 1)/
                    fcb       C$CR,C$LF
                    fcc       /Physical scratch blocks: $10 and $11 (fm11-headless)/
                    fcb       C$CR,C$LF
HeaderEnd           equ       *

WindowMsg           fcc       /Logical test window: $/
WindowMsgEnd        equ       *
PhysMsg             fcc       / (4 KiB)/
                    fcb       C$CR,C$LF
PhysMsgEnd          equ       *

PassMsg             fcc       /PASS: MMR read-back and two 4K physical pages are independent./
                    fcb       C$CR,C$LF
PassMsgEnd          equ       *

FailMsg             fcc       /FAIL: code $/
FailMsgEnd          equ       *
BlockMsg            fcc       /MMR logical block: $/
BlockMsgEnd         equ       *
OffsetMsg           fcc       /Failure offset: $/
OffsetMsgEnd        equ       *
ExpectedMsg         fcc       / expected=$/
ExpectedMsgEnd      equ       *
ActualMsg           fcc       / actual=$/
ActualMsgEnd        equ       *
CodeMsg             fcc       /Codes: 01=already enabled, 02=no window, 03=identity read-back,/
                    fcb       C$CR,C$LF
                    fcc       /       04=A map read-back, 05=B map read-back, 06=A data, 07=B data./
                    fcb       C$CR,C$LF
CodeMsgEnd          equ       *
CRLF                fcb       C$CR,C$LF
CRLFEnd             equ       *

                    emod
eom                 equ       *
                    end
