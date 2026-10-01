********************************************************************
* MMUTest2 - FM-11 MMR task-switching diagnostic for NitrOS-9 L1
*
* Second-stage MMU test for the FM-11 Level 2 port.
*
* This command runs under NitrOS-9 Level 1 and verifies that two MMR
* task banks can map the same 4 KiB logical page to different physical
* pages while all other logical pages remain identity-mapped.
*
* Requirements / assumptions:
*   - Run under the FM-11 NitrOS-9 Level 1 v39 environment.
*   - MMR must be disabled on entry (FD93 bit 7 = 0).
*   - Extended RAM must cover physical 4 KiB blocks $10 and $11
*     ($10000-$11FFF).  Level 1 does not allocate memory above 64 KiB,
*     so these blocks are scratch space while this test is running.
*   - The contents of physical blocks $10 and $11 are destroyed.
*
* Test sequence:
*   1. Choose a 4K-aligned logical page wholly inside this process'
*      private scratch area.
*   2. Save MMR banks for the current task and one alternate task.
*   3. Build identity maps for both tasks, except that the logical test
*      page maps to physical $10 in task A and physical $11 in task B.
*   4. Enable MMR in task A and fill the logical page with pattern A.
*   5. Switch only FD90 to task B and fill the same logical page with
*      pattern B.
*   6. Switch repeatedly between task A and B and verify that each task
*      still sees its own pattern at the identical logical address.
*   7. Disable MMR and restore both task banks, FD90, FD93 and CC.
*
* No OS-9 system call is made while MMR is enabled.
********************************************************************

                    nam       MMUTest2
                    ttl       FM-11 MMR task-switching diagnostic

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       2

FM11_MMR_BASE       equ       $FD80
FM11_MMR_TASK       equ       $FD90
FM11_MMR_ENABLE     equ       $80

PhysBlockA          equ       $10
PhysBlockB          equ       $11

* Status codes returned in Status:
*   0 = PASS
*   1 = MMR was already enabled on entry
*   2 = no safe logical test window found
*   3 = task A map read-back failed
*   4 = task B map read-back failed
*   5 = task A data verify failed
*   6 = task B data verify failed

                    mod       eom,name,tylg,atrv,start,size

                    org       0
Status              rmb       1
SavedCC             rmb       1
SavedTask           rmb       1
AltTask             rmb       1
SavedCtl            rmb       1
WindowBlock         rmb       1
FailTask            rmb       1
FailBlock           rmb       1
FailExpected        rmb       1
FailActual          rmb       1
WindowAddr          rmb       2
FailOffset          rmb       2
HexValue            rmb       2
HexBuf              rmb       4
SavedMMRA           rmb       16
SavedMMRB           rmb       16
                    rmb       32

* 12 KiB guarantees a complete 4 KiB-aligned page after excluding a
* special logical page.  StackReserve is kept outside the remapped page.
Scratch             rmb       $3000
ScratchEnd          equ       *
StackReserve        rmb       $0200
size                equ       .

name                fcs       /MMUTest2/
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
                    leax      CRLF,pcr
                    ldy       #CRLFEnd-CRLF
                    lbsr      Put

                    lbsr      RunTest

* RunTest has restored Level 1 mapping; it is safe to report task numbers.
                    leax      TaskPairMsg,pcr
                    ldy       #TaskPairMsgEnd-TaskPairMsg
                    lbsr      Put
                    lda       SavedTask,u
                    lbsr      PutHex8
                    leax      TaskSepMsg,pcr
                    ldy       #TaskSepMsgEnd-TaskSepMsg
                    lbsr      Put
                    lda       AltTask,u
                    lbsr      PutHex8
                    leax      CRLF,pcr
                    ldy       #CRLFEnd-CRLF
                    lbsr      Put

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
                    lblo      FailText
                    cmpa      #4
                    lbhi      FailData

* Status 3..4: show task and logical MMR block for read-back failure.
                    leax      TaskMsg,pcr
                    ldy       #TaskMsgEnd-TaskMsg
                    lbsr      Put
                    lda       FailTask,u
                    lbsr      PutHex8
                    leax      BlockMsg,pcr
                    ldy       #BlockMsgEnd-BlockMsg
                    lbsr      Put
                    lda       FailBlock,u
                    lbsr      PutHex8
                    leax      CRLF,pcr
                    ldy       #CRLFEnd-CRLF
                    lbsr      Put
                    lbra      FailText

FailData            cmpa      #5
                    lblo      FailText
                    cmpa      #6
                    lbhi      FailText
                    leax      TaskMsg,pcr
                    ldy       #TaskMsgEnd-TaskMsg
                    lbsr      Put
                    lda       FailTask,u
                    lbsr      PutHex8
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
* MMR is disabled on entry.  IRQ/FIRQ are masked for the entire period
* during which task maps are modified or MMR is enabled.
********************************************************************
RunTest             tfr       cc,a
                    sta       SavedCC,u
                    orcc      #IntMasks

                    lda       >FM11_MMR_TASK
                    anda      #$0F
                    sta       SavedTask,u
                    inca
                    anda      #$0F
                    sta       AltTask,u

                    lda       >FM11_ROMCTL
                    sta       SavedCtl,u

* Save task A MMR bank.
                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    leay      SavedMMRA,u
                    ldb       #16
SaveALoop           lda       ,x+
                    sta       ,y+
                    decb
                    bne       SaveALoop

* Save task B MMR bank.
                    lda       AltTask,u
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    leay      SavedMMRB,u
                    ldb       #16
SaveBLoop           lda       ,x+
                    sta       ,y+
                    decb
                    bne       SaveBLoop

* Program task A with identity mapping.
                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    clra
                    ldb       #16
InitALoop           sta       ,x
                    cmpa      ,x
                    lbne      IdentAFail
                    leax      1,x
                    inca
                    decb
                    bne       InitALoop

* Override the logical test page in task A with physical block A.
                    ldb       WindowBlock,u
                    ldx       #FM11_MMR_BASE
                    abx
                    lda       #PhysBlockA
                    sta       ,x
                    cmpa      ,x
                    lbne      MapAFail

* Program task B with identity mapping.
                    lda       AltTask,u
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    clra
                    ldb       #16
InitBLoop           sta       ,x
                    cmpa      ,x
                    lbne      IdentBFail
                    leax      1,x
                    inca
                    decb
                    bne       InitBLoop

* Override the same logical page in task B with physical block B.
                    ldb       WindowBlock,u
                    ldx       #FM11_MMR_BASE
                    abx
                    lda       #PhysBlockB
                    sta       ,x
                    cmpa      ,x
                    lbne      MapBFail

* Select task A before enabling MMR.  Every non-test logical page is
* identity-mapped in both task banks, so code, data and stack remain valid
* when FD90 is subsequently switched between A and B.
                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    lda       SavedCtl,u
                    ora       #FM11_MMR_ENABLE
                    sta       >FM11_ROMCTL

* Task A: fill its physical page with 00,01,...,FF repeated over 4 KiB.
                    ldx       WindowAddr,u
                    ldy       #$1000
                    clra
FillA               sta       ,x+
                    inca
                    leay      -1,y
                    bne       FillA

* Task B: the identical logical address must now select physical block $11.
                    lda       AltTask,u
                    sta       >FM11_MMR_TASK
                    ldx       WindowAddr,u
                    ldy       #$1000
                    lda       #$FF
FillB               sta       ,x+
                    deca
                    leay      -1,y
                    bne       FillB

* Switch back to task A and verify pattern A.
                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    ldx       WindowAddr,u
                    ldy       #$1000
                    clra
VerifyA             cmpa      ,x
                    lbne      DataAFail
                    leax      1,x
                    inca
                    leay      -1,y
                    bne       VerifyA

* Switch to task B and verify pattern B.
                    lda       AltTask,u
                    sta       >FM11_MMR_TASK
                    ldx       WindowAddr,u
                    ldy       #$1000
                    lda       #$FF
VerifyB             cmpa      ,x
                    lbne      DataBFail
                    leax      1,x
                    deca
                    leay      -1,y
                    bne       VerifyB

* One more A/B/A switch with fixed sentinels catches task-bank aliasing
* without relying only on the sequential patterns above.
                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    ldx       WindowAddr,u
                    lda       #$5A
                    sta       ,x

                    lda       AltTask,u
                    sta       >FM11_MMR_TASK
                    ldx       WindowAddr,u
                    lda       #$A5
                    sta       ,x

                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    ldx       WindowAddr,u
                    lda       #$5A
                    cmpa      ,x
                    lbne      DataAFail

                    lda       AltTask,u
                    sta       >FM11_MMR_TASK
                    ldx       WindowAddr,u
                    lda       #$A5
                    cmpa      ,x
                    lbne      DataBFail

                    clr       Status,u
                    lbra      Restore

IdentAFail          sta       FailBlock,u
                    lda       SavedTask,u
                    sta       FailTask,u
                    lda       #3
                    sta       Status,u
                    lbra      Restore

IdentBFail          sta       FailBlock,u
                    lda       AltTask,u
                    sta       FailTask,u
                    lda       #4
                    sta       Status,u
                    lbra      Restore

MapAFail            lda       SavedTask,u
                    sta       FailTask,u
                    lda       WindowBlock,u
                    sta       FailBlock,u
                    lda       #3
                    sta       Status,u
                    lbra      Restore

MapBFail            lda       AltTask,u
                    sta       FailTask,u
                    lda       WindowBlock,u
                    sta       FailBlock,u
                    lda       #4
                    sta       Status,u
                    lbra      Restore

DataAFail           sta       FailExpected,u
                    ldb       ,x
                    stb       FailActual,u
                    tfr       x,d
                    subd      WindowAddr,u
                    std       FailOffset,u
                    lda       SavedTask,u
                    sta       FailTask,u
                    lda       #5
                    sta       Status,u
                    lbra      Restore

DataBFail           sta       FailExpected,u
                    ldb       ,x
                    stb       FailActual,u
                    tfr       x,d
                    subd      WindowAddr,u
                    std       FailOffset,u
                    lda       AltTask,u
                    sta       FailTask,u
                    lda       #6
                    sta       Status,u

* Disable MMR before restoring either saved task bank.  This guarantees that
* arbitrary pre-test mappings cannot hide the running code/data/stack.
Restore             lda       SavedCtl,u
                    anda      #$7F
                    sta       >FM11_ROMCTL

* Restore task A bank.
                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    leay      SavedMMRA,u
                    ldb       #16
RestoreALoop        lda       ,y+
                    sta       ,x+
                    decb
                    bne       RestoreALoop

* Restore task B bank.
                    lda       AltTask,u
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    leay      SavedMMRB,u
                    ldb       #16
RestoreBLoop        lda       ,y+
                    sta       ,x+
                    decb
                    bne       RestoreBLoop

                    lda       SavedTask,u
                    sta       >FM11_MMR_TASK
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
                    lbra      Put

PutHex8             leax      HexBuf,u
                    bsr       StoreHexByte
                    leax      HexBuf,u
                    ldy       #2
                    lbra      Put

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

Header              fcc       /FM-11 MMR task test v2 (NitrOS-9 Level 1)/
                    fcb       C$CR,C$LF
                    fcc       /Uses physical blocks $10 and $11 as scratch extended RAM./
                    fcb       C$CR,C$LF
HeaderEnd           equ       *

WindowMsg           fcc       /Logical test window: $/
WindowMsgEnd        equ       *
TaskPairMsg         fcc       /Task A: $/
TaskPairMsgEnd      equ       *
TaskSepMsg          fcc       /  Task B: $/
TaskSepMsgEnd       equ       *

PassMsg             fcc       /PASS: task banks map one logical 4K page independently./
                    fcb       C$CR,C$LF
PassMsgEnd          equ       *

FailMsg             fcc       /FAIL: code $/
FailMsgEnd          equ       *
TaskMsg             fcc       /Task: $/
TaskMsgEnd          equ       *
BlockMsg            fcc       / logical block: $/
BlockMsgEnd         equ       *
OffsetMsg           fcc       / offset: $/
OffsetMsgEnd        equ       *
ExpectedMsg         fcc       / expected=$/
ExpectedMsgEnd      equ       *
ActualMsg           fcc       / actual=$/
ActualMsgEnd        equ       *
CodeMsg             fcc       /Codes: 01=already enabled, 02=no window, 03=task A map,/
                    fcb       C$CR,C$LF
                    fcc       /       04=task B map, 05=task A data, 06=task B data./
                    fcb       C$CR,C$LF
CodeMsgEnd          equ       *
CRLF                fcb       C$CR,C$LF
CRLFEnd             equ       *

                    emod
eom                 equ       *
                    end
