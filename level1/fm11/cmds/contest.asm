********************************************************************
* ConTest - FM-11 ANSI/VT100 console and erase translation test
*
* v31-fixed2 diagnostic command.  The validated SGR tests are retained and
* ANSI CSI K/J/X are tested through the /Term native erase translation.
********************************************************************

                    nam       ConTest
                    ttl       FM-11 ANSI console and erase test

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       7

                    mod       eom,name,tylg,atrv,start,size

                    org       0
Key                 rmb       1
                    rmb       63
size                equ       .

name                fcs       /ConTest/
                    fcb       edition

start               leax      Header,pcr
                    ldy       #HeaderEnd-Header
                    lbsr      Put

                    leax      Test1,pcr
                    ldy       #Test1End-Test1
                    lbsr      Put
                    lbsr      WaitKey
                    leax      Normal,pcr
                    ldy       #NormalEnd-Normal
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test2,pcr
                    ldy       #Test2End-Test2
                    lbsr      Put
                    lbsr      WaitKey
                    leax      Colors,pcr
                    ldy       #ColorsEnd-Colors
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test3,pcr
                    ldy       #Test3End-Test3
                    lbsr      Put
                    lbsr      WaitKey
                    leax      Bright,pcr
                    ldy       #BrightEnd-Bright
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test4,pcr
                    ldy       #Test4End-Test4
                    lbsr      Put
                    lbsr      WaitKey
                    leax      Reverse,pcr
                    ldy       #ReverseEnd-Reverse
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test5,pcr
                    ldy       #Test5End-Test5
                    lbsr      Put
                    lbsr      WaitKey
                    leax      Bold,pcr
                    ldy       #BoldEnd-Bold
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test6,pcr
                    ldy       #Test6End-Test6
                    lbsr      Put
                    lbsr      WaitKey
                    leax      Blink,pcr
                    ldy       #BlinkEnd-Blink
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test7,pcr
                    ldy       #Test7End-Test7
                    lbsr      Put
                    lbsr      WaitKey
                    leax      Combined,pcr
                    ldy       #CombinedEnd-Combined
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test8,pcr
                    ldy       #Test8End-Test8
                    lbsr      Put
                    lbsr      WaitKey
                    leax      EraseT,pcr
                    ldy       #EraseTEnd-EraseT
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test9,pcr
                    ldy       #Test9End-Test9
                    lbsr      Put
                    lbsr      WaitKey
                    leax      EraseY,pcr
                    ldy       #EraseYEnd-EraseY
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test10,pcr
                    ldy       #Test10End-Test10
                    lbsr      Put
                    lbsr      WaitKey
                    leax      EraseJ2,pcr
                    ldy       #EraseJ2End-EraseJ2
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test11,pcr
                    ldy       #Test11End-Test11
                    lbsr      Put
                    lbsr      WaitKey
                    leax      EraseX,pcr
                    ldy       #EraseXEnd-EraseX
                    lbsr      Put
                    lbsr      WaitKey

                    leax      Test12,pcr
                    ldy       #Test12End-Test12
                    lbsr      Put
                    lbsr      WaitKey
                    leax      EraseK2,pcr
                    ldy       #EraseK2End-EraseK2
                    lbsr      Put

                    leax      Footer,pcr
                    ldy       #FooterEnd-Footer
                    lbsr      Put
                    clrb
Exit                os9       F$Exit

Put                 lda       #1
                    os9       I$Write
                    bcs       Exit
                    rts

WaitKey             leax      Key,u
                    ldy       #1
                    lda       #0
                    os9       I$Read
                    bcs       Exit

* /Term has echo enabled, so the key just read has already been displayed.
* Return to column 1 before the SGR test so the echoed key is overwritten and
* does not shift the diagnostic output by one character.
                    leax      WaitCR,pcr
                    ldy       #1
                    lda       #1
                    os9       I$Write
                    bcs       Exit
                    rts

WaitCR              fcb       C$CR

ESC                 equ       $1B

Header              fcc       /FM-11 ANSI console and erase translation test/
                    fcb       C$CR,C$LF
                    fcc       !SGR tests are followed by ANSI CSI K/J/X erase tests.!
                    fcb       C$CR,C$LF
                    fcc       /Press a key to run each test, observe the result, then press another key./
                    fcb       C$CR,C$LF
HeaderEnd           equ       *

Test1               fcc       /TEST 1: SGR 0 reset/
                    fcb       C$CR,C$LF
Test1End            equ       *

Test2               fcc       /TEST 2: SGR 30-37 base colors/
                    fcb       C$CR,C$LF
Test2End            equ       *

Test3               fcc       /TEST 3: SGR 90-97 bright colors/
                    fcb       C$CR,C$LF
Test3End            equ       *

Test4               fcc       /TEST 4: SGR 7 reverse video/
                    fcb       C$CR,C$LF
Test4End            equ       *

Test5               fcc       /TEST 5: SGR 1 bold-intensity/
                    fcb       C$CR,C$LF
Test5End            equ       *

Test6               fcc       /TEST 6: SGR 5 blink/
                    fcb       C$CR,C$LF
Test6End            equ       *

Test7               fcc       /TEST 7: combined red, bright and reverse/
                    fcb       C$CR,C$LF
Test7End            equ       *

Test8               fcc       /TEST 8: ANSI CSI 0K erase to end of line/
                    fcb       C$CR,C$LF
                    fcc       /Expected after run: only ABCDE remains on the test line./
                    fcb       C$CR,C$LF
Test8End            equ       *

Test9               fcc       /TEST 9: ANSI CSI 0J erase to end of screen/
                    fcb       C$CR,C$LF
                    fcc       /Expected: KEEP-1 remains; second line becomes KEEP; later setup lines vanish./
                    fcb       C$CR,C$LF
Test9End            equ       *

Test10              fcc       /TEST 10: ANSI CSI 2J erase whole screen, preserve cursor/
                    fcb       C$CR,C$LF
                    fcc       /Expected: screen clears; PASS CSI 2J appears at row 3 column 10./
                    fcb       C$CR,C$LF
Test10End           equ       *

Test11              fcc       /TEST 11: ANSI CSI 3X erase three characters/
                    fcb       C$CR,C$LF
                    fcc       /Expected after run: ABCDE   IJ remains on the test line./
                    fcb       C$CR,C$LF
Test11End           equ       *

Test12              fcc       /TEST 12: ANSI CSI 2K erase whole line, preserve cursor/
                    fcb       C$CR,C$LF
                    fcc       /Expected: old text vanishes; X appears at column 6./
                    fcb       C$CR,C$LF
Test12End           equ       *

Normal              fcb       ESC
                    fcc       /[0m/
                    fcc       !SGR 0 normal/default!
                    fcb       C$CR,C$LF
NormalEnd           equ       *

Colors              fcb ESC
                    fcc /[30mBLACK /
                    fcb ESC
                    fcc /[31mRED /
                    fcb ESC
                    fcc /[32mGREEN /
                    fcb ESC
                    fcc /[33mYELLOW /
                    fcb ESC
                    fcc /[34mBLUE /
                    fcb ESC
                    fcc /[35mMAGENTA /
                    fcb ESC
                    fcc /[36mCYAN /
                    fcb ESC
                    fcc /[37mWHITE/
                    fcb ESC
                    fcc /[0m/
                    fcb C$CR,C$LF
ColorsEnd           equ       *

Bright              fcb ESC
                    fcc /[90mB.BLACK /
                    fcb ESC
                    fcc /[91mB.RED /
                    fcb ESC
                    fcc /[92mB.GREEN /
                    fcb ESC
                    fcc /[93mB.YELLOW /
                    fcb ESC
                    fcc /[94mB.BLUE /
                    fcb ESC
                    fcc /[95mB.MAGENTA /
                    fcb ESC
                    fcc /[96mB.CYAN /
                    fcb ESC
                    fcc /[97mB.WHITE/
                    fcb ESC
                    fcc /[0m/
                    fcb C$CR,C$LF
BrightEnd           equ       *

Reverse             fcb ESC
                    fcc /[7mREVERSE VIDEO/
                    fcb ESC
                    fcc /[27m normal/
                    fcb C$CR,C$LF
ReverseEnd          equ       *

Bold                fcb ESC
                    fcc /[1mBOLD-INTENSITY/
                    fcb ESC
                    fcc /[22m normal/
                    fcb C$CR,C$LF
BoldEnd             equ       *

Blink               fcb ESC
                    fcc /[5mBLINK TEST/
                    fcb ESC
                    fcc /[25m normal  (emulator renderer currently ignores blink bit)/
                    fcb C$CR,C$LF
BlinkEnd            equ       *

Combined             fcb ESC
                    fcc /[31m/
                    fcb ESC
                    fcc /[1m/
                    fcb ESC
                    fcc /[7mBRIGHT RED REVERSE/
                    fcb ESC
                    fcc /[0m/
                    fcb C$CR,C$LF
CombinedEnd         equ       *

* CSI 0K test: same setup previously used to validate native ESC T, but now
* pass through the ANSI parser and /Term translation.
EraseT              fcc       /ABCDEFGHIJ/
                    fcb       C$CR
                    fcb       ESC
                    fcc       /[5C/
                    fcb       ESC
                    fcc       /[0K/
                    fcb       C$CR,C$LF
EraseTEnd           equ       *

* CSI 0J test: same setup previously used to validate native ESC Y.
EraseY              fcc       /KEEP-1/
                    fcb       C$CR,C$LF
                    fcc       /KEEP-2-ERASE-REST/
                    fcb       C$CR,C$LF
                    fcc       /ERASE-ME-TOO/
                    fcb       C$CR,C$LF
                    fcb       ESC
                    fcc       /[2A/
                    fcb       C$CR
                    fcb       ESC
                    fcc       /[4C/
                    fcb       ESC
                    fcc       /[0J/
                    fcb       C$CR,C$LF
EraseYEnd           equ       *

* CSI 2J must erase the whole screen without changing the ANSI cursor.  Put the
* cursor at row 3 column 10 first; PASS should therefore appear there afterwards.
EraseJ2             fcb       ESC
                    fcc       /[3;10H/
                    fcb       ESC
                    fcc       /[2J/
                    fcc       /PASS CSI 2J/
                    fcb       C$CR,C$LF
EraseJ2End          equ       *

* CSI 3X must blank F,G,H without moving the cursor or affecting I,J.
EraseX              fcc       /ABCDEFGHIJ/
                    fcb       C$CR
                    fcb       ESC
                    fcc       /[5C/
                    fcb       ESC
                    fcc       /[3X/
                    fcb       C$CR,C$LF
EraseXEnd           equ       *

* CSI 2K is the sequence used by More to remove its prompt.  The erase must
* not wrap/scroll and must preserve the cursor at column 6.
EraseK2             fcc       /ABCDEFGHIJ/
                    fcb       C$CR
                    fcb       ESC
                    fcc       /[5C/
                    fcb       ESC
                    fcc       /[2K/
                    fcc       /X/
                    fcb       C$CR,C$LF
EraseK2End          equ       *

Footer              fcc       /ANSI erase translation diagnostics complete./
                    fcb       C$CR,C$LF
FooterEnd           equ       *

                    emod
eom                 equ       *
                    end
