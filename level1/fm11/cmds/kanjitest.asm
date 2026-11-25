********************************************************************
* KanjiTest - enhanced FM-11 stock sub-ROM Kanji display test
* Uses shared command mailbox; never accesses Kanji ROM or VRAM.
********************************************************************
                    nam       KanjiTest
                    ttl       FM-11 JIS level 1/2 stock-ROM test
                    ifp1
                    use       defsfile
                    endc
tylg                set       Prgrm+Objct
rev                 set       0
atrv                set       ReEnt+rev
edition             set       1
                    mod       eom,name,tylg,atrv,start,size
                    org       0
                    rmb       32
size                equ       .
name                fcs       /KanjiTest/
                    fcb       edition

SUB_PORT            equ       $FD05
SUB_SHARED          equ       $FC80
* Main-side graphics display gate (text remains enabled).
DISPLAY_CTRL        equ       $FDA0
DISPLAY_BOTH        equ       $0D
SUB_CHAR            equ       $12
SUB_SJIS            equ       $37
TIMEOUT             equ       $FFFF

start               leax      Header,pcr
                    ldy       #HeaderEnd-Header
                    lbsr      Put
                    bcs       Fail
* Firmware uses graphics VRAM for Kanji. A text-only FDA0 setting
* masks that VRAM at SDL scanout even when AFF4-7 reads succeed.
* Enable both graphics ($0C) and text ($01) before printing.
                    lda       #DISPLAY_BOTH
                    sta       >DISPLAY_CTRL
* Stock enhanced sub-ROM $37 at EAF4: FC83=$FF enables the
* Shift-JIS interpretation flag (direct RAM $9C, bit 7).  $01
* instead CLEARS it, so the byte pairs are displayed as ANK.
* FC84/FC85 are both initialized to zero by Cmd.
                    lda       #SUB_SJIS
                    ldb       #$FF
                    lbsr      Cmd
                    bcs       Fail
                    leax      Samples,pcr
                    lbsr      Stream
                    pshs      cc
                    lda       #SUB_SJIS
                    clrb
                    lbsr      Cmd
                    bcs       RestoreFail
                    puls      cc
                    bcs       Fail
                    bra       Restored
RestoreFail         leas      1,s
                    bra       Fail
Restored
                    leax      Footer,pcr
                    ldy       #FooterEnd-Footer
                    lbsr      Put
                    bcs       Fail
                    clrb
Exit                os9       F$Exit
Fail                ldb       #1
                    bra       Exit

* Zero-terminated Shift-JIS stream, including ASCII labels.
Stream              ldb       ,x+
                    beq       StreamEnd
                    lda       #SUB_CHAR
                    lbsr      Cmd
                    bcs       StreamEnd
                    bra       Stream
StreamEnd           rts

* A command, B first argument. Preserve A/B/X.
* Protocol follows fm11console.asm ScreenPutC.
Cmd                 pshs      a,b,x
                    ldx       #TIMEOUT
CmdReady            lda       >SUB_PORT
                    bpl       CmdHalt
                    leax      -1,x
                    bne       CmdReady
                    bra       CmdFail
CmdHalt             lda       #$80
                    sta       >SUB_PORT
                    ldx       #TIMEOUT
CmdHaltWait         lda       >SUB_PORT
                    bmi       CmdInstall
                    leax      -1,x
                    bne       CmdHaltWait
                    clr       >SUB_PORT
                    bra       CmdFail
CmdInstall          clr       >SUB_SHARED
                    clr       >SUB_SHARED+1
* PSHS A,B,X stores A at 0,S and B at 1,S;
* 2,S and 3,S are the saved X, not command parameters.
                    lda       0,s
                    sta       >SUB_SHARED+2
                    lda       1,s
                    sta       >SUB_SHARED+3
                    clr       >SUB_SHARED+4
                    clr       >SUB_SHARED+5
                    clr       >SUB_PORT
                    ldx       #TIMEOUT
CmdWait             lda       >SUB_PORT
                    bpl       CmdOK
                    leax      -1,x
                    bne       CmdWait
CmdFail             orcc      #Carry
                    puls      a,b,x,pc
CmdOK               andcc     #^Carry
                    puls      a,b,x,pc

Put                 lda       #1
                    os9       I$Write
                    rts

Header              fcc       /FM-11 stock sub-ROM Kanji test (JIS 1 and 2)/
                    fcb       C$CR,C$LF
HeaderEnd           equ       *

* Level 1: Kan/Ji/Ni/Hon/Go/A. Level 2: JIS78 48-1..48-5.
* Raw Shift-JIS bytes, not UTF-8 or graphics/ROM addresses.
Samples             fcc       /Level 1: /
                    fcb       $8A,$BF,$8E,$9A,$93,$FA,$96,$7B
                    fcb       $8C,$EA,$88,$9F,$0D,$0A
                    fcc       /Level 2: /
                    fcb       $98,$9F,$98,$A0,$98,$A1,$98,$A2,$98,$A3
                    fcb       $0D,$0A,0

Footer              fcc       /Done. Check on-screen glyphs and --trace-kanji./
                    fcb       C$CR,C$LF
FooterEnd           equ       *
                    emod
eom                 equ       *
                    end
