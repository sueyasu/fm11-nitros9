********************************************************************
* Boot - FM-11 MDC hard disk Boot module
*
* RBF LSN0 begins at physical sector 32.  boot_common follows DD.BT,
* including the fragmented OS9Boot form used by FM-11 OS9Gen/Cobbler.
********************************************************************
                    nam       Boot
                    ttl       FM-11 MDC hard disk Boot module
                    ifp1
                    use       defsfile
                    endc
BootReserveSectors  equ       32
MDCResultReady      equ       $40
MDCError            equ       $80
MDCBinaryMask       equ       $70
MDCDMA2Select       equ       $20
rev                 set       $00
edition             set       1
tylg                set       Systm+Objct
atrv                set       ReEnt+rev
                    mod       eom,name,tylg,atrv,start,size
seglist             rmb       2
blockloc            rmb       2
blockimg            rmb       2
bootsize            rmb       2
LSN0Ptr             rmb       2
ddtks               rmb       1
ddfmt               rmb       1
hwlba               rmb       3
size                equ       .
name                fcs       /Boot/
                    fcb       edition
LSN24BIT            equ       1
FLOPPY              equ       0

HWInit              lda       #MDCDMA2Select
                    sta       >FM11_MDC_SELECT
                    lda       #FM11_MDC_SETCMASK
                    sta       >FM11_MDC_CMD
                    lda       #MDCBinaryMask
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    lbsr      WaitResult
                    rts
HWTerm              clrb
                    andcc     #^Carry
                    rts
                    use       boot_common.asm

* Entry: B,X = 24-bit RBF LSN; blockloc,U = destination.
HWRead              pshs      b
                    tfr       x,d
                    addd      #BootReserveSectors
                    tfr       d,x
                    puls      b
                    adcb      #0
                    stb       hwlba,u
                    stx       hwlba+1,u
                    ldx       blockloc,u
                    clr       >FM11_DMA2_ADDR_H
                    stx       >FM11_DMA2_ADDR_M
                    lda       #1
                    sta       >FM11_DMA2_COUNT_H
                    clr       >FM11_DMA2_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA2_MODE
                    lda       #FM11_MDC_READ
                    sta       >FM11_MDC_CMD
                    clr       >FM11_MDC_DATA       parameter 0: drive 0
                    clr       >FM11_MDC_DATA       parameter 1
                    clr       >FM11_MDC_DATA       address bits 31..24
                    lda       hwlba,u
                    sta       >FM11_MDC_DATA       address bits 23..16
                    lda       hwlba+1,u
                    sta       >FM11_MDC_DATA       address bits 15..8
                    lda       hwlba+2,u
                    sta       >FM11_MDC_DATA       address bits 7..0
                    lda       #1
                    sta       >FM11_MDC_DATA       byte count = $0100
                    clr       >FM11_MDC_DATA
                    lbsr      WaitResult
                    bcs       HWR_Bad
                    lda       >FM11_DMA2_MODE
                    bita      #FM11_DMA_ERROR
                    bne       HWR_Bad
                    bita      #FM11_DMA_DONE
                    beq       HWR_Bad
                    ldx       blockloc,u
                    clrb
                    andcc     #^Carry
                    rts
HWR_Bad             orcc      #Carry
                    ldb       #E$Read
                    rts

WaitResult          pshs      x
                    ldx       #$FFFF
WR_Wait             lda       >FM11_MDC_STATUS
                    bita      #MDCResultReady
                    bne       WR_Ready
                    leax      -1,x
                    bne       WR_Wait
                    puls      x
                    orcc      #Carry
                    ldb       #E$NotRdy
                    rts
WR_Ready            lda       >FM11_MDC_DATA
                    pshs      a
                    ldb       #9
WR_Drain            lda       >FM11_MDC_DATA
                    decb
                    bne       WR_Drain
                    puls      a
                    puls      x
                    bita      #MDCError
                    bne       WR_Error
                    clrb
                    andcc     #^Carry
                    rts
WR_Error            orcc      #Carry
                    ldb       #E$Read
                    rts
Address             fdb       FM11_MDC_CMD
                    emod
eom                 equ       *
                    end
