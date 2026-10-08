********************************************************************
* fm11console - Fujitsu FM-11 local-screen SCF driver for Level 2
*
* Initial Level 2 port of the proven Level 1 local console.
*
* Output uses the FM-11 Display Sub System CHARACTER OUT command
* through the shared command area at $FC80.
*
* Keyboard input uses INKEY 2 ($2D). ASCII/control keys are returned
* directly.  DEL and the four cursor keys use the same normalization
* as the Level 1 driver.
*
* This first Level 2 version deliberately keeps output handling small:
* bytes supplied by SCF are passed directly to the FM-11 character
* console.  The full Level 1 ANSI/VT100 parser can be brought over
* after the basic Level 2 console path is proven.
********************************************************************

                    nam       fm11console
                    ttl       Fujitsu FM-11 Level 2 Local Console SCF Driver

                    ifp1
                    use       defsfile
                    endc

FM11_SUB_SHARED     equ       $FC80
SUB_CHAR_OUT        equ       $12
SUB_INKEY2          equ       $2D
SUB_WAIT_MAX        equ       $FFFF
SCR_COLS            equ       80
SCR_ROWS            equ       25

                    org       V.SCF
V.KbdValid          rmb       1
V.KbdChar           rmb       1
MemSize             equ       .

rev                 set       0
edition             set       1

                    mod       ModSize,ModName,Drivr+Objct,ReEnt+rev,ModEntry,MemSize

                    fcb       UPDAT.

ModName             fcs       /fm11console/
                    fcb       edition

********************************************************************
* Driver jump table
********************************************************************
ModEntry            lbra      Init
                    lbra      Read
                    lbra      Write
                    lbra      GStt
                    lbra      SStt
                    lbra      Term

********************************************************************
* Init / Term
********************************************************************
Init                clr       V.KbdValid,u
                    clr       V.KbdChar,u
                    lda       #C$Clsall
                    lbsr      ScreenPutC
                    bcs       InitExit
                    lda       #C$HOME
                    lbsr      ScreenPutC
InitExit            rts

Term                clrb
                    andcc     #^Carry
                    rts

********************************************************************
* Read
********************************************************************
Read                tst       V.KbdValid,u
                    beq       ReadPoll
                    lda       V.KbdChar,u
                    clr       V.KbdValid,u
                    bra       ReadDone

ReadPoll            lbsr      KeyboardPoll
                    bcs       ReadYield
                    tstb
                    bne       ReadReady
ReadYield           ldx       #1
                    os9       F$Sleep
                    bra       ReadPoll

ReadReady           lda       V.KbdChar,u
                    clr       V.KbdValid,u
ReadDone            clrb
                    andcc     #^Carry
                    rts

********************************************************************
* Write
*
* A = character/control byte from SCF.
********************************************************************
Write               lbsr      ScreenPutC
                    rts

********************************************************************
* GetStat
********************************************************************
GStt                pshs      dp
                    pshs      a
                    tfr       u,d
                    tfr       a,dp
                    puls      a

                    cmpa      #SS.EOF
                    beq       GSOk
                    cmpa      #SS.Ready
                    beq       GSReady
                    cmpa      #SS.ScSiz
                    beq       GSScSiz

                    ldb       #E$UnkSvc
                    orcc      #Carry
                    puls      dp,pc

GSReady             lbsr      KeyboardPoll
                    bcs       GSNotReady
                    tstb
                    beq       GSNotReady
                    ldx       PD.RGS,y
                    ldb       #1
                    stb       R$B,x
                    bra       GSOk

GSNotReady          ldb       #E$NotRdy
                    orcc      #Carry
                    puls      dp,pc

GSScSiz             ldx       PD.RGS,y
                    ldd       #SCR_COLS
                    std       R$X,x
                    ldd       #SCR_ROWS
                    std       R$Y,x

GSOk                clrb
                    andcc     #^Carry
                    puls      dp,pc

********************************************************************
* SetStat
********************************************************************
SStt                cmpa      #SS.Open
                    beq       SSOk
                    cmpa      #SS.Close
                    beq       SSOk
                    cmpa      #SS.ComSt
                    beq       SSOk
                    cmpa      #SS.HngUp
                    beq       SSOk
                    cmpa      #SS.Break
                    beq       SSOk

                    ldb       #E$UnkSvc
                    orcc      #Carry
                    rts

SSOk                clrb
                    andcc     #^Carry
                    rts

********************************************************************
* KeyboardPoll
*
* Return:
*   B = 1 if a character is queued
*   B = 0 if no supported key is available
*   C = set on subsystem timeout
********************************************************************
KeyboardPoll        tst       V.KbdValid,u
                    beq       KPFetch
                    ldb       #1
                    andcc     #^Carry
                    rts

KPFetch             pshs      y
                    ldy       V.PORT,u
                    ldx       #SUB_WAIT_MAX
KPWaitReady         lda       ,y
                    bpl       KPHalt
                    leax      -1,x
                    bne       KPWaitReady
                    lbra      KPFail

KPHalt              lda       #$80
                    sta       ,y
                    ldx       #SUB_WAIT_MAX
KPWaitHalt          lda       ,y
                    bmi       KPInstall
                    leax      -1,x
                    bne       KPWaitHalt
                    clr       ,y
                    lbra      KPFail

KPInstall           clr       >FM11_SUB_SHARED
                    clr       >FM11_SUB_SHARED+1
                    lda       #SUB_INKEY2
                    sta       >FM11_SUB_SHARED+2
                    clr       >FM11_SUB_SHARED+3
                    clr       >FM11_SUB_SHARED+4

                    clr       ,y
                    ldx       #SUB_WAIT_MAX
KPWaitDone          lda       ,y
                    bpl       KPResult
                    leax      -1,x
                    bne       KPWaitDone
                    lbra      KPFail

KPResult            lda       >FM11_SUB_SHARED+3
                    beq       KPAscii

* $01xx extended keys confirmed by the Level 1 console:
*   $0114 DEL, $0116 UP, $0117 DOWN, $0118 LEFT, $0119 RIGHT.
                    cmpa      #$01
                    bne       KPExtIgnored
                    lda       >FM11_SUB_SHARED+4
                    cmpa      #$14
                    beq       KPDelete
                    cmpa      #$16
                    beq       KPUp
                    cmpa      #$17
                    beq       KPDown
                    cmpa      #$18
                    beq       KPLeft
                    cmpa      #$19
                    beq       KPRight
                    bra       KPExtIgnored

KPDelete            lda       #$7F
                    bra       KPOneByte

* Cursor keys are useful to echo-off/raw applications.  Cooked SCF input
* ignores them, matching the Level 1 implementation.
KPUp                lda       #$80
                    bra       KPCursor
KPDown              lda       #$81
                    bra       KPCursor
KPLeft              lda       #$82
                    bra       KPCursor
KPRight             lda       #$83
KPCursor            ldx       ,s
                    tst       PD.EKO,x
                    bne       KPExtIgnored

KPOneByte           sta       V.KbdChar,u
                    lda       #1
                    sta       V.KbdValid,u
                    ldb       #1
                    andcc     #^Carry
                    puls      y,pc

KPExtIgnored        clrb
                    andcc     #^Carry
                    puls      y,pc

KPAscii             lda       >FM11_SUB_SHARED+4
                    sta       V.KbdChar,u
                    lda       #1
                    sta       V.KbdValid,u
                    ldb       #1
                    andcc     #^Carry
                    puls      y,pc

KPFail              clrb
                    orcc      #Carry
                    puls      y,pc

********************************************************************
* ScreenPutC
*
* A = FM-11 character/control byte
********************************************************************
ScreenPutC          pshs      a,b,x,y
                    tfr       a,b
                    ldy       V.PORT,u

                    ldx       #SUB_WAIT_MAX
SPCWaitReady        lda       ,y
                    bpl       SPCHalt
                    leax      -1,x
                    bne       SPCWaitReady
                    bra       SPCFail

SPCHalt             lda       #$80
                    sta       ,y
                    ldx       #SUB_WAIT_MAX
SPCWaitHalt         lda       ,y
                    bmi       SPCInstall
                    leax      -1,x
                    bne       SPCWaitHalt
                    clr       ,y
                    bra       SPCFail

SPCInstall          clr       >FM11_SUB_SHARED
                    clr       >FM11_SUB_SHARED+1
                    lda       #SUB_CHAR_OUT
                    sta       >FM11_SUB_SHARED+2
                    stb       >FM11_SUB_SHARED+3

                    clr       ,y
                    ldx       #SUB_WAIT_MAX
SPCWaitDone         lda       ,y
                    bpl       SPCDone
                    leax      -1,x
                    bne       SPCWaitDone
                    bra       SPCFail

SPCDone             andcc     #^Carry
                    puls      a,b,x,y,pc

SPCFail             orcc      #Carry
                    puls      a,b,x,y,pc

                    emod
ModSize             equ       *
                    end
