*******************************************************************
* REL - FM-11 Level 1 relocation routine
*
* FM-11-specific Level 1 REL for NitrOS-9 bring-up.
*
* Responsibilities:
*   - mask interrupts while relocating
*   - disable FM-11 boot ROM window ($5000-$5FFF -> RAM)
*   - initialize USART0 for the system console
*   - relocate the boot track from $2600 to Bt.Start
*   - initialize 6809 hardware vectors to NitrOS-9 stubs at $0100
*   - enter the following KRN module
*******************************************************************

                    nam       REL
                    ttl       FM-11 Level 1 Relocation routine

                    IFP1
                    use       defsfile
                    ENDC

XX.Size             equ       6
Offset              equ       Bt.Start+XX.Size

tylg                set       Systm+Objct
atrv                set       ReEnt+rev
rev                 set       $06
edition             set       1

********************************************************************
* The boot loader jumps to $2602.  Keep these six bytes compatible
* with the standard Level 1 kernelfile layout.
********************************************************************
                    fcc       /OS/
                    bra       (Start+XX.Size+*-2)
                    fdb       $1205

Begin               mod       eom,name,tylg,atrv,Start,size

                    org       0
size                equ       .

name                fcs       /REL/
                    fcb       edition

********************************************************************
* Entry point -- no stack is available here.
********************************************************************
Start
                    orcc      #IntMasks

* Disable the FM-11 boot ROM window at $5000-$5FFF.  This exposes
* the RAM underneath before NitrOS-9 starts managing memory.
                    lda       >FM11_ROMCTL
                    ora       #FM11_ROM_RAM
                    sta       >FM11_ROMCTL

* Initialize USART0 (async x16, 8N1; TX/RX enable).
                    lda       #$4E
                    sta       >UART_CTRL
                    lda       #$37
                    sta       >UART_CTRL


********************************************************************
* Relocate the complete Level 1 boot image.
*
* Bt.Start for FM-11 must keep the whole Bt.Size-byte image below
* $FC00 because $FC00-$FFFF is not ordinary RAM on this machine.
********************************************************************
CopyTrack           leau      >Begin-XX.Size,pcr
                    ldx       #Bt.Size
                    ldy       #Bt.Start
CopyLoop            lda       ,u+
                    sta       ,y+
                    leax      -1,x
                    bne       CopyLoop

* Continue in the relocated copy.
                    jmp       >Offset+Relocated

********************************************************************
* Now executing from high RAM.
********************************************************************
Relocated

* NitrOS-9 KRN installs its vector stubs at $0100-$0111.  Point the
* 6809 hardware vectors at those locations before the first OS-9 SWI2
* (F$Link) can occur.
*
*   $0100 SWI3
*   $0103 SWI2
*   $0106 SWI
*   $0109 NMI
*   $010C IRQ
*   $010F FIRQ
                    ldd       #$0100
                    std       >$FFF2
                    ldd       #$0103
                    std       >$FFF4
                    ldd       #$010F
                    std       >$FFF6
                    ldd       #$010C
                    std       >$FFF8
                    ldd       #$0106
                    std       >$FFFA
                    ldd       #$0109
                    std       >$FFFC

* The module immediately following REL must be KRN.
                    leax      <eom,pcr
                    ldd       M$Exec,x
                    jmp       d,x


                    emod
eom                 equ       *
                    end
