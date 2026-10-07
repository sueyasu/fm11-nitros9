********************************************************************
* REL - FM-11 Level 2 relocation routine, 8 KiB-pair DAT model
*
* The ROM IPL loads a fixed $1500-byte kernel-track image at $2600:
*
*   $0000-$012F  REL
*   $0130-$027F  Boot slot
*   $0280-$147F  Krn slot
*   $1480-$14FF  disk padding
*
* REL relocates only the first Bt.Size=$1480 bytes to $E780-$FBFF.
* The final $80 bytes are deliberately not copied into fixed RAM.
*
* Task 0 is initialized as a 16-page 4 KiB identity map.  This is the
* hardware representation of the standard eight-block 8 KiB system DAT.
********************************************************************

                    nam       REL
                    ttl       FM-11 Level 2 relocation routine

                    IFP1
                    use       defsfile
                    ENDC

XX.Size             equ       6
Offset              equ       Bt.Start+XX.Size
KrnStart            equ       $EA00
VCT.Ct              equ       6
VCT.Sz              equ       3

                  IFNE    H6309
SWIStkSz            equ       17
                  ELSE
SWIStkSz            equ       15
                  ENDC

tylg                set       Systm+Objct
atrv                set       ReEnt+rev
rev                 set       $06
edition             set       1

                    fcc       /OS/
                    bra       (Start+XX.Size+*-2)
                    fdb       $1205

Begin               mod       eom,name,tylg,atrv,Start,size

                    org       0
size                equ       .

name                fcs       /REL/
                    fcb       edition

Start
                    orcc      #IntMasks

                    lda       #$4E
                    sta       >UART_CTRL
                    lda       #$37
                    sta       >UART_CTRL

* Hardware task 0: identity-map all sixteen 4 KiB pages.
                    clra
                    sta       >FM11_MMR_TASK
                    ldx       #FM11_MMR_BASE
                    ldb       #FM11_MMR_PAGES
MapTask0            sta       ,x+
                    inca
                    decb
                    bne       MapTask0

                    lda       >FM11_MMR_CTRL
                    ora       #FM11_ROM_RAM+FM11_MMR_ENABLE
                    sta       >FM11_MMR_CTRL

                    leau      >Begin-XX.Size,pcr
                    ldx       #Bt.Size
                    ldy       #Bt.Start
CopyTrack           lda       ,u+
                    sta       ,y+
                    leax      -1,x
                    bne       CopyTrack

                    jmp       >Offset+Relocated

Relocated
                    clra
                    tfr       a,dp

                    ldx       #$0000
                    clrb
ClearDP             sta       ,x+
                    incb
                    bne       ClearDP

                    lds       #$1FFF

                  IFNE    H6309
                    ldmd      #3
                    inc       <D.MDREG
                  ENDC

* Disable normal boot diagnostics.  All common loader/kernel progress
* output goes through D.BtBug, so an RTS here keeps normal boot silent.
                    lda       #$39
                    sta       <D.BtBug

                    lda       #$7E
                    sta       <D.Crash
                    leax      <Crash,pcr
                    stx       <D.Crash+1

* Temporary task-0-only vectors until FM11Trmp installs fixed-RAM vectors.
                    ldx       #KrnStart
                    ldd       M$Size,x
                    leax      d,x
                    leax      SWIStkSz,x
                    ldy       #$FFF2
                    ldb       #VCT.Ct
SetVector           stx       ,y++
                    leax      VCT.Sz,x
                    decb
                    bne       SetVector

                    ldx       #KrnStart
                    ldd       M$Exec,x
                    jmp       d,x

BtDebug             pshs      cc,b
                    anda      #$7F
BtDebugWait         ldb       >UART_CTRL
                    bitb      #UART_TXRDY
                    beq       BtDebugWait
                    sta       >UART_DATA
                    puls      cc,b,pc

Crash               lda       #'!
                    bsr       BtDebug
CrashLoop           bra       CrashLoop

Filler              fill      $00,$130-XX.Size-3-*

                    emod
eom                 equ       *
                    end
