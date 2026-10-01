********************************************************************
* fm11console - Fujitsu FM-11 local-screen SCF Driver
*
* v30 local console with provisional ANSI/VT100 SGR translation.
*
* Output is sent to the FM-11 Display Sub System through the shared
* command area at $FC80.  ANSI CSI sequences are translated to the
* native FM-11 cursor/clear controls before reaching CHARACTER OUT.
*
* Supported output sequences:
*   ESC [ n A/B/C/D       cursor relative motion
*   ESC [ row ; col H/f   cursor position
*   ESC [ n G             absolute column
*   ESC [ n d             absolute row
*   ESC [ n J             erase display (0/1/2; 2 is native clear)
*   ESC [ n K             erase line (0/1/2)
*   ESC [ n X             erase n characters
*   ESC [ ... m           SGR -> FM-11 native video attribute (provisional)
*   ESC [ s / ESC [ u     save/restore cursor
*   ESC 7 / ESC 8         save/restore cursor (VT100)
*   ESC c                 terminal reset (clear + home)
*   ESC [ ? 25 h/l        cursor show/hide accepted as no-op
*
* Screen size is reported as 80x25.  Cursor positioning is implemented
* with the already-proven FM-11 HOME/UP/DOWN/LEFT/RIGHT controls, so no
* new Display Sub System command assumptions are introduced.
*
* Keyboard input uses INKEY 2 ($2D). ASCII/control keys are returned
* directly. Confirmed FM-11 DEL and four cursor keys are normalized to
* conventional terminal input ($7F and ANSI ESC[A/B/C/D respectively).
* Other extended/special keys remain ignored for now.
********************************************************************

                    nam       fm11console
                    ttl       Fujitsu FM-11 ANSI Local Console SCF Driver

                    ifp1
                    use       defsfile
                    endc

FM11_SUB_SHARED     equ       $FC80
SUB_CHAR_OUT        equ       $12
SUB_INKEY2          equ       $2D
SUB_WAIT_MAX        equ       $FFFF
ANSI_ESC            equ       $1B
ANSI_NORMAL         equ       0
ANSI_ESCSTATE       equ       1
ANSI_CSI            equ       2
SCR_COLS            equ       80
SCR_ROWS            equ       25

                    org       V.SCF
V.KbdValid          rmb       1
V.KbdChar           rmb       1
V.KbdSeqCount       rmb       1
V.KbdSeq1           rmb       1
V.KbdSeq2           rmb       1
V.AnsiState         rmb       1
V.AnsiParam         rmb       1
V.AnsiPrivate       rmb       1
V.AnsiP1            rmb       1
V.AnsiP2            rmb       1
V.CurRow            rmb       1
V.CurCol            rmb       1
V.SaveRow           rmb       1
V.SaveCol           rmb       1
V.TmpRow            rmb       1
V.TmpCol            rmb       1
V.WorkRow           rmb       1
V.WorkCol           rmb       1
V.LineRow           rmb       1
V.LineCol           rmb       1
V.NativeAttr        rmb       1
MemSize             equ       .

rev                 set       0
edition             set       13

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
* Init
********************************************************************
Init                clr       V.KbdValid,u
                    clr       V.KbdChar,u
                    clr       V.KbdSeqCount,u
                    clr       V.KbdSeq1,u
                    clr       V.KbdSeq2,u
                    clr       V.AnsiState,u
                    clr       V.AnsiParam,u
                    clr       V.AnsiPrivate,u
                    clr       V.AnsiP1,u
                    clr       V.AnsiP2,u
                    clr       V.TmpRow,u
                    clr       V.TmpCol,u
                    clr       V.WorkRow,u
                    clr       V.WorkCol,u
                    clr       V.LineRow,u
                    clr       V.LineCol,u
                    lda       #$07
                    sta       V.NativeAttr,u
                    lda       #1
                    sta       V.CurRow,u
                    sta       V.CurCol,u
                    sta       V.SaveRow,u
                    sta       V.SaveCol,u
                    lda       #C$Clsall
                    lbsr      ScreenPutC
                    lda       #C$HOME
                    lbsr      ScreenPutC
                    clrb
                    andcc     #^Carry
                    rts

********************************************************************
* Term
********************************************************************
Term                clrb
                    andcc     #^Carry
                    rts

********************************************************************
* Read
********************************************************************
Read                tst       V.KbdValid,u
                    beq       ReadPoll
                    clr       V.KbdValid,u
                    lda       V.KbdChar,u
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
* A = byte from SCF. ANSI/VT100 escapes are consumed here and translated
* to the FM-11 native character-screen controls. Ordinary bytes retain
* the v20 behavior.
********************************************************************
Write               lbsr      AnsiPutC
                    clrb
                    andcc     #^Carry
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
                    ldd       #80
                    std       R$X,x
                    ldd       #25
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
* ANSI/VT100 output parser
********************************************************************
AnsiPutC            ldb       V.AnsiState,u
                    beq       APNormal
                    cmpb      #ANSI_ESCSTATE
                    beq       APEsc
                    lbra      APCsi

APNormal            cmpa      #ANSI_ESC
                    bne       APOrdinary
                    lda       #ANSI_ESCSTATE
                    sta       V.AnsiState,u
                    andcc     #^Carry
                    rts

APOrdinary          lbsr      RawPutCTracked
                    rts

* One byte after ESC.
APEscapeReset       clr       V.AnsiState,u
                    andcc     #^Carry
                    rts

APEsc               cmpa      #'[
                    beq       APStartCsi
                    cmpa      #'7
                    beq       APSave
                    cmpa      #'8
                    beq       APRestore
                    cmpa      #'c
                    beq       APResetTerm
                    cmpa      #'D
                    beq       APIndex
                    cmpa      #'M
                    beq       APReverseIndex
                    cmpa      #'E
                    beq       APNextLine
* FM-11 native erase controls are also accepted directly.  ANSI K/J/X use
* the same validated controls internally where their semantics match.
                    cmpa      #'T
                    beq       APNativeEsc
                    cmpa      #'Y
                    beq       APNativeEsc
                    cmpa      #'*
                    beq       APNativeEsc
* Unknown ESC sequence: consume it rather than emitting garbage.
                    bra       APEscapeReset

APNativeEsc         pshs      a
                    lda       #ANSI_ESC
                    lbsr      ScreenPutC
                    puls      a
                    lbsr      ScreenPutC
                    clr       V.AnsiState,u
                    andcc     #^Carry
                    rts

APStartCsi          lda       #ANSI_CSI
                    sta       V.AnsiState,u
                    clr       V.AnsiParam,u
                    clr       V.AnsiPrivate,u
                    clr       V.AnsiP1,u
                    clr       V.AnsiP2,u
                    andcc     #^Carry
                    rts

APSave              lda       V.CurRow,u
                    sta       V.SaveRow,u
                    lda       V.CurCol,u
                    sta       V.SaveCol,u
                    bra       APEscapeReset

APRestore           lda       V.SaveRow,u
                    ldb       V.SaveCol,u
                    lbsr      AnsiGoto
                    clr       V.AnsiState,u
                    rts

APResetTerm         lbsr      AnsiClearHome
                    clr       V.AnsiState,u
                    rts

APIndex             lda       #C$DWN
                    lbsr      RawPutCTracked
                    clr       V.AnsiState,u
                    rts

APReverseIndex      lda       #C$UP
                    lbsr      RawPutCTracked
                    clr       V.AnsiState,u
                    rts

APNextLine          lda       #C$DWN
                    lbsr      RawPutCTracked
                    lda       #C$CR
                    lbsr      RawPutCTracked
                    clr       V.AnsiState,u
                    rts

* CSI parser.  Two numeric parameters are sufficient for the supported set.
APCsi               cmpa      #'0
                    blo       APCsiNotDigit
                    cmpa      #'9
                    bhi       APCsiNotDigit
                    suba      #'0
                    pshs      a
                    tst       V.AnsiParam,u
                    bne       APCsiDigit2
                    lda       #10
                    ldb       V.AnsiP1,u
                    mul
                    addb      ,s+
                    stb       V.AnsiP1,u
                    andcc     #^Carry
                    rts
APCsiDigit2         lda       #10
                    ldb       V.AnsiP2,u
                    mul
                    addb      ,s+
                    stb       V.AnsiP2,u
                    andcc     #^Carry
                    rts

APCsiNotDigit       cmpa      #';
                    bne       APCsiPrivate
                    lda       #1
                    sta       V.AnsiParam,u
                    andcc     #^Carry
                    rts

APCsiPrivate        cmpa      #'?
                    bne       APCsiFinal
                    lda       #1
                    sta       V.AnsiPrivate,u
                    andcc     #^Carry
                    rts

APCsiFinal          pshs      a
                    clr       V.AnsiState,u
                    puls      a
                    cmpa      #'A
                    lbeq      APCursorUp
                    cmpa      #'B
                    lbeq      APCursorDown
                    cmpa      #'C
                    lbeq      APCursorRight
                    cmpa      #'D
                    lbeq      APCursorLeft
                    cmpa      #'E
                    lbeq      APCursorNextLine
                    cmpa      #'F
                    lbeq      APCursorPrevLine
                    cmpa      #'H
                    lbeq      APCursorPos
                    cmpa      #'f
                    lbeq      APCursorPos
                    cmpa      #'G
                    lbeq      APAbsCol
                    cmpa      #'d
                    lbeq      APAbsRow
                    cmpa      #'J
                    lbeq      APEraseDisplay
                    cmpa      #'K
                    lbeq      APEraseLine
                    cmpa      #'X
                    lbeq      APEraseChars
                    cmpa      #'m
                    lbeq      APSgr
                    cmpa      #'s
                    lbeq      APCsiSave
                    cmpa      #'u
                    lbeq      APCsiRestore
                    cmpa      #'h
                    lbeq      APCsiMode
                    cmpa      #'l
                    lbeq      APCsiMode
* Unsupported final byte is deliberately ignored.
                    andcc     #^Carry
                    rts

* Return B=P1 with ANSI default 1.
APGetCount          ldb       V.AnsiP1,u
                    bne       APCountOk
                    ldb       #1
APCountOk           rts

APCursorUp          lbsr      APGetCount
APCUlp              cmpb      #0
                    beq       APCUDone
                    lda       #C$UP
                    lbsr      RawPutCTracked
                    decb
                    bra       APCUlp
APCUDone            andcc     #^Carry
                    rts

APCursorDown        lbsr      APGetCount
APCDlp              cmpb      #0
                    beq       APCUDone
                    lda       #C$DWN
                    lbsr      RawPutCTracked
                    decb
                    bra       APCDlp

APCursorRight       lbsr      APGetCount
APCRlp              cmpb      #0
                    beq       APCUDone
                    lda       #C$RGT
                    lbsr      RawPutCTracked
                    decb
                    bra       APCRlp

APCursorLeft        lbsr      APGetCount
APCLlp              cmpb      #0
                    beq       APCUDone
                    lda       #C$LFT
                    lbsr      RawPutCTracked
                    decb
                    bra       APCLlp


APCursorNextLine    lbsr      APGetCount
APCNLoop            cmpb      #0
                    beq       APCNCR
                    lda       #C$DWN
                    lbsr      RawPutCTracked
                    decb
                    bra       APCNLoop
APCNCR              lda       #C$CR
                    lbsr      RawPutCTracked
                    rts

APCursorPrevLine    lbsr      APGetCount
APCPLoop            cmpb      #0
                    beq       APCPCR
                    lda       #C$UP
                    lbsr      RawPutCTracked
                    decb
                    bra       APCPLoop
APCPCR              lda       #C$CR
                    lbsr      RawPutCTracked
                    rts

APCursorPos         lda       V.AnsiP1,u
                    bne       APCPRowOk
                    lda       #1
APCPRowOk           ldb       V.AnsiP2,u
                    bne       APCPColOk
                    ldb       #1
APCPColOk           lbsr      AnsiGoto
                    rts

APAbsCol            lda       V.CurRow,u
                    ldb       V.AnsiP1,u
                    bne       APACOk
                    ldb       #1
APACOk              lbsr      AnsiGoto
                    rts

APAbsRow            lda       V.AnsiP1,u
                    bne       APAROk
                    lda       #1
APAROk              ldb       V.CurCol,u
                    lbsr      AnsiGoto
                    rts

APEraseDisplay      ldb       V.AnsiP1,u
                    cmpb      #2
                    beq       APEDAll
                    cmpb      #1
                    beq       APEDStart
* CSI 0 J: native erase from cursor through end of screen.
                    lbsr      AnsiEraseToEnd
                    rts
APEDStart           lbsr      AnsiEraseFromStart
                    rts
* CSI 2 J: native full-screen erase homes the hardware cursor, so restore the
* ANSI cursor position afterwards.  ANSI ED 2 does not move the cursor.
APEDAll             lda       V.CurRow,u
                    sta       V.WorkRow,u
                    lda       V.CurCol,u
                    sta       V.WorkCol,u
                    lbsr      NativeEraseAll
                    lda       V.WorkRow,u
                    ldb       V.WorkCol,u
                    lbsr      AnsiGoto
                    rts

APEraseLine         ldb       V.AnsiP1,u
                    lbsr      AnsiEraseLine
                    rts

APEraseChars        lbsr      APGetCount
                    lbsr      AnsiEraseChars
                    rts

* ANSI SGR -> FM-11 native video attribute.
*
* Emulator-confirmed character attribute byte:
*   bits 0..2 = color, bit 3 = reverse, bit 4 = blink, bit 5 = bold/intensity.
*
* The FM-11/CP-M console documentation identifies ESC G as Video Attribute.
* v30 provisionally passes the complete native attribute byte as the byte
* following ESC G.  contest is provided specifically to validate this path.
*
* Supported SGR parameters in v30:
*   0 reset, 1 bold/intensity, 5 blink, 7 reverse
*   22/25/27 corresponding off controls
*   30..37 foreground colors, 39 default white
*   90..97 bright foreground colors
* Background SGR is intentionally ignored: the emulator character-cell
* renderer has no independent background-color field.
APSgr               lda       V.AnsiP1,u
                    lbsr      ApplySgrParam
                    tst       V.AnsiParam,u
                    beq       APSgrApply
                    lda       V.AnsiP2,u
                    lbsr      ApplySgrParam
APSgrApply           lbsr      ApplyNativeAttr
                    andcc     #^Carry
                    rts

ApplySgrParam       cmpa      #0
                    beq       ASPReset
                    cmpa      #1
                    beq       ASPBold
                    cmpa      #5
                    beq       ASPBlink
                    cmpa      #7
                    beq       ASPReverse
                    cmpa      #22
                    beq       ASPBoldOff
                    cmpa      #25
                    beq       ASPBlinkOff
                    cmpa      #27
                    beq       ASPReverseOff
                    cmpa      #39
                    beq       ASPDefaultColor
                    cmpa      #30
                    blo       ASPBrightCheck
                    cmpa      #37
                    bhi       ASPBrightCheck
                    suba      #30
                    lbsr      ASPSetColor
                    rts
ASPBrightCheck      cmpa      #90
                    blo       ASPDone
                    cmpa      #97
                    bhi       ASPDone
                    suba      #90
                    lbsr      ASPSetColor
                    ldb       V.NativeAttr,u
                    orb       #$20
                    stb       V.NativeAttr,u
ASPDone             rts

ASPReset            lda       #$07
                    sta       V.NativeAttr,u
                    rts
ASPBold             ldb       V.NativeAttr,u
                    orb       #$20
                    stb       V.NativeAttr,u
                    rts
ASPBlink            ldb       V.NativeAttr,u
                    orb       #$10
                    stb       V.NativeAttr,u
                    rts
ASPReverse          ldb       V.NativeAttr,u
                    orb       #$08
                    stb       V.NativeAttr,u
                    rts
ASPBoldOff          ldb       V.NativeAttr,u
                    andb      #$DF
                    stb       V.NativeAttr,u
                    rts
ASPBlinkOff         ldb       V.NativeAttr,u
                    andb      #$EF
                    stb       V.NativeAttr,u
                    rts
ASPReverseOff       ldb       V.NativeAttr,u
                    andb      #$F7
                    stb       V.NativeAttr,u
                    rts
ASPDefaultColor     lda       #7
                    lbsr      ASPSetColor
                    rts

* A = ANSI color index 0..7. Convert ANSI RGB ordering to FM-11 B/R/G bit order:
* black,red,green,yellow,blue,magenta,cyan,white -> 0,2,4,6,1,3,5,7.
ASPSetColor         leax      AnsiColorMap,pcr
                    lda       a,x
                    pshs      a
                    ldb       V.NativeAttr,u
                    andb      #$F8
                    orb       ,s+
                    stb       V.NativeAttr,u
                    rts

ApplyNativeAttr     lda       #ANSI_ESC
                    lbsr      ScreenPutC
                    lda       #'G
                    lbsr      ScreenPutC
                    lda       V.NativeAttr,u
                    lbsr      ScreenPutC
                    rts

AnsiColorMap        fcb       0,2,4,6,1,3,5,7

APCsiSave           lda       V.CurRow,u
                    sta       V.SaveRow,u
                    lda       V.CurCol,u
                    sta       V.SaveCol,u
                    andcc     #^Carry
                    rts

APCsiRestore        lda       V.SaveRow,u
                    ldb       V.SaveCol,u
                    lbsr      AnsiGoto
                    rts

* DEC private modes (notably ?25h/?25l cursor visibility) are accepted.
* Cursor shape/visibility is owned by the FM-11 display subsystem and is
* deliberately left unchanged until that interface is confirmed.
APCsiMode           andcc     #^Carry
                    rts

********************************************************************
* AnsiGoto
*   A=row (1..25), B=column (1..80)
*
* The FM-11 character console natively accepts the three-byte cursor-address
* order $12,X,Y where X=0..79 and Y=0..24.  Translate ANSI 1-based row/column
* directly to that native order.
********************************************************************
AnsiGoto            cmpa      #1
                    bhs       AGRowLowOk
                    lda       #1
AGRowLowOk          cmpa      #SCR_ROWS
                    bls       AGRowOk
                    lda       #SCR_ROWS
AGRowOk             cmpb      #1
                    bhs       AGColLowOk
                    ldb       #1
AGColLowOk          cmpb      #SCR_COLS
                    bls       AGColOk
                    ldb       #SCR_COLS
AGColOk             sta       V.TmpRow,u
                    stb       V.TmpCol,u

                    lda       #$12
                    lbsr      ScreenPutC
                    lda       V.TmpCol,u
                    deca
                    lbsr      ScreenPutC
                    lda       V.TmpRow,u
                    deca
                    lbsr      ScreenPutC

                    lda       V.TmpRow,u
                    sta       V.CurRow,u
                    lda       V.TmpCol,u
                    sta       V.CurCol,u
                    andcc     #^Carry
                    rts

AnsiClearHome       lda       #C$Clsall
                    lbsr      ScreenPutC
                    lda       #C$HOME
                    lbsr      ScreenPutC
                    lda       #1
                    sta       V.CurRow,u
                    sta       V.CurCol,u
                    andcc     #^Carry
                    rts

********************************************************************
* Erase helpers
********************************************************************
* Native FM-11 erase controls validated by ConTest:
*   ESC T  cursor through end of line, cursor unchanged
*   ESC Y  cursor through end of screen, cursor unchanged
*   ESC *  whole screen, native cursor homed
*
* B=mode: 0 cursor->EOL, 1 BOL->cursor, 2 whole line.
AnsiEraseLine       lda       V.CurRow,u
                    sta       V.LineRow,u
                    lda       V.CurCol,u
                    sta       V.LineCol,u
                    cmpb      #1
                    beq       AELStart
                    cmpb      #2
                    beq       AELAll
* CSI 0 K maps directly to native erase-to-end-of-line.
                    lbsr      NativeEraseEOL
                    rts

* CSI 1 K has no native backward-erase equivalent.  Erase only the requested
* cells.  EraseCells never writes through the right margin: if its range reaches
* column 80 it uses native ESC T instead of emitting the final wrapping space.
AELStart            lda       V.LineRow,u
                    ldb       #1
                    lbsr      AnsiGoto
                    ldb       V.LineCol,u
                    lbsr      EraseCells
                    bra       AELRestore

* CSI 2 K: go to column 1, native ESC T, then restore the ANSI cursor.
AELAll              lda       V.LineRow,u
                    ldb       #1
                    lbsr      AnsiGoto
                    lbsr      NativeEraseEOL
AELRestore          lda       V.LineRow,u
                    ldb       V.LineCol,u
                    lbsr      AnsiGoto
                    rts

* B=count.  Keep logical and physical cursor unchanged when complete.
AnsiEraseChars      lda       V.CurRow,u
                    sta       V.LineRow,u
                    lda       V.CurCol,u
                    sta       V.LineCol,u
                    lbsr      EraseCells
                    lda       V.LineRow,u
                    ldb       V.LineCol,u
                    lbsr      AnsiGoto
                    rts

* B=count, erase starting at the current cursor without updating V.CurRow/Col.
* If count reaches or passes the right margin, native ESC T is exactly the ANSI
* ECH result after clipping to the current line and avoids any wrap/scroll.
EraseCells          cmpb      #0
                    beq       ECDone
                    lda       #SCR_COLS+1
                    suba      V.CurCol,u
                    sta       V.TmpCol,u
                    cmpb      V.TmpCol,u
                    bhs       ECToEOL
ECSpaces            cmpb      #0
                    beq       ECDone
                    pshs      b
                    lda       #C$SPAC
                    lbsr      ScreenPutC
                    puls      b
                    decb
                    bra       ECSpaces
ECToEOL             lbsr      NativeEraseEOL
ECDone              rts

* CSI 0 J maps directly to native ESC Y and leaves the cursor unchanged.
AnsiEraseToEnd      lbsr      NativeEraseEOS
                    rts

* CSI 1 J has no native backward-erase equivalent.  Full preceding lines use
* CSI 2 K's native path; only the current line prefix needs bounded spaces.
AnsiEraseFromStart  lda       V.CurRow,u
                    sta       V.WorkRow,u
                    lda       V.CurCol,u
                    sta       V.WorkCol,u
                    lda       #1
AEFSrow             cmpa      V.WorkRow,u
                    bhs       AEFSCurrent
                    sta       V.TmpRow,u
                    ldb       #1
                    lbsr      AnsiGoto
                    ldb       #2
                    lbsr      AnsiEraseLine
                    lda       V.TmpRow,u
                    inca
                    bra       AEFSrow
AEFSCurrent         lda       V.WorkRow,u
                    ldb       V.WorkCol,u
                    lbsr      AnsiGoto
                    ldb       #1
                    lbsr      AnsiEraseLine
                    lda       V.WorkRow,u
                    ldb       V.WorkCol,u
                    lbsr      AnsiGoto
                    rts

NativeEraseEOL      lda       #ANSI_ESC
                    lbsr      ScreenPutC
                    lda       #'T
                    lbsr      ScreenPutC
                    rts

NativeEraseEOS      lda       #ANSI_ESC
                    lbsr      ScreenPutC
                    lda       #'Y
                    lbsr      ScreenPutC
                    rts

NativeEraseAll      lda       #ANSI_ESC
                    lbsr      ScreenPutC
                    lda       #'*
                    lbsr      ScreenPutC
                    rts

********************************************************************
* RawPutCTracked
* A = native FM-11 output/control byte.
********************************************************************
RawPutCTracked      pshs      a
                    lbsr      ScreenPutC
                    puls      a
                    cmpa      #C$CR
                    beq       RPCR
                    cmpa      #C$LF
                    beq       RPLF
                    cmpa      #C$BSP
                    beq       RPLeft
                    cmpa      #C$LFT
                    beq       RPLeft
                    cmpa      #C$RGT
                    beq       RPRight
                    cmpa      #C$UP
                    beq       RPUp
                    cmpa      #C$DWN
                    beq       RPDown
                    cmpa      #C$HOME
                    beq       RPHome
                    cmpa      #C$Clsall
                    beq       RPHome
                    cmpa      #C$FORM
                    beq       RPHome
                    cmpa      #C$SPAC
                    blo       RPDone
* Printable character.
                    lda       V.CurCol,u
                    cmpa      #SCR_COLS
                    blo       RPIncCol
                    lda       #1
                    sta       V.CurCol,u
                    lda       V.CurRow,u
                    cmpa      #SCR_ROWS
                    bhs       RPDone
                    inca
                    sta       V.CurRow,u
                    bra       RPDone
RPIncCol            inca
                    sta       V.CurCol,u
                    bra       RPDone
RPCR                lda       #1
                    sta       V.CurCol,u
                    bra       RPDone
RPLF                lda       V.CurRow,u
                    cmpa      #SCR_ROWS
                    bhs       RPDone
                    inca
                    sta       V.CurRow,u
                    bra       RPDone
RPLeft              lda       V.CurCol,u
                    cmpa      #1
                    bls       RPDone
                    deca
                    sta       V.CurCol,u
                    bra       RPDone
RPRight             lda       V.CurCol,u
                    cmpa      #SCR_COLS
                    bhs       RPDone
                    inca
                    sta       V.CurCol,u
                    bra       RPDone
RPUp                 lda       V.CurRow,u
                    cmpa      #1
                    bls       RPDone
                    deca
                    sta       V.CurRow,u
                    bra       RPDone
RPDown              lda       V.CurRow,u
                    cmpa      #SCR_ROWS
                    bhs       RPDone
                    inca
                    sta       V.CurRow,u
                    bra       RPDone
RPHome              lda       #1
                    sta       V.CurRow,u
                    sta       V.CurCol,u
RPDone              andcc     #^Carry
                    rts

********************************************************************
* KeyboardPoll
********************************************************************
KeyboardPoll        tst       V.KbdValid,u
                    beq       KPQueued
                    ldb       #1
                    andcc     #^Carry
                    rts

* No multi-byte input escape queue is used.  Extended cursor keys are
* normalized to one-byte raw key codes for echo-off applications.
KPQueued            bra       KPFetch

KPFetch             pshs      y
                    ldy       V.PORT,u
                    ldx       #SUB_WAIT_MAX
KPWaitReady         lda       ,y
                    bpl       KPHalt
                    leax      -1,x
                    cmpx      #0
                    bne       KPWaitReady
                    lbra      KPFail

KPHalt              lda       #$80
                    sta       ,y
                    ldx       #SUB_WAIT_MAX
KPWaitHalt          lda       ,y
                    bmi       KPInstall
                    leax      -1,x
                    cmpx      #0
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
                    cmpx      #0
                    bne       KPWaitDone
                    lbra      KPFail

KPResult            lda       >FM11_SUB_SHARED+3
                    beq       KPAscii
* Confirmed FM-11 extended keys:
*   $0114 DEL   -> $7F
*   $0116 UP    -> $80
*   $0117 DOWN  -> $81
*   $0118 LEFT  -> $82
*   $0119 RIGHT -> $83
*
* Cursor keys are returned only on echo-off paths (screen editors/raw input).
* Cooked/echo-on SCF input such as the Shell prompt ignores them; classic SCF
* has no ANSI input-sequence parser, so returning ESC [ A/B/C/D would merely
* echo "[A" etc. as ordinary text.  DEL remains available in either mode.
                    cmpa      #$01
                    beq       KPExtended
* $02xx special keys, including FM-11 BREAK/Pause ($0201), are ignored.
* BREAK proved unsafe for old applications with asynchronous signal-stack
* handling; Ctrl-C remains the normal OS-9 interrupt key.
                    bra       KPExtIgnored

KPExtended          lda       >FM11_SUB_SHARED+4
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

* Y currently addresses the FM-11 port.  The caller's original path
* descriptor was saved by "pshs y" at KPFetch and is still at ,s.
* Only raw/echo-off paths receive editor cursor-key codes.
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

KPExtIgnored        ldb       #0
                    andcc     #^Carry
                    puls      y,pc

KPAscii             lda       >FM11_SUB_SHARED+4
                    sta       V.KbdChar,u
                    lda       #1
                    sta       V.KbdValid,u
                    ldb       #1
                    andcc     #^Carry
                    puls      y,pc

KPFail              ldb       #0
                    orcc      #Carry
                    puls      y,pc

********************************************************************
* ScreenPutC
********************************************************************
ScreenPutC          pshs      a,b,x,y
                    tfr       a,b
                    ldy       V.PORT,u

                    ldx       #SUB_WAIT_MAX
SPCWaitReady        lda       ,y
                    bpl       SPCHalt
                    leax      -1,x
                    cmpx      #0
                    bne       SPCWaitReady
                    bra       SPCFail

SPCHalt             lda       #$80
                    sta       ,y
                    ldx       #SUB_WAIT_MAX
SPCWaitHalt         lda       ,y
                    bmi       SPCInstall
                    leax      -1,x
                    cmpx      #0
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
                    cmpx      #0
                    bne       SPCWaitDone
                    bra       SPCFail

SPCDone             andcc     #^Carry
                    puls      a,b,x,y,pc

SPCFail             orcc      #Carry
                    puls      a,b,x,y,pc

                    emod
ModSize             equ       *
                    end
