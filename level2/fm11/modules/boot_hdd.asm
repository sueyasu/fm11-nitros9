********************************************************************
* Boot - FM-11 Level 2 MDC hard disk Boot module
*
* Physical sectors:
*   0-1   ROM IPL
*   2-22  21-sector Level 2 kernel track
*   23-   RBF filesystem (LSN0 == physical sector 23)
********************************************************************
                    nam       Boot
                    ttl       FM-11 Level 2 MDC hard disk Boot module

                    ifp1
                    use       defsfile
                    endc

BootReserveSectors  equ       23
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

* The HDD IPL has already selected DMA2 and put the MDC into binary-sector
* address mode immediately before loading REL/Boot.  Repeating SETCMASK here
* costs 22 bytes and is unnecessary on the only path that can enter this
* booter.  Preserve that controller state and merely report successful init.
HWInit              andcc     #^Carry
                    rts

HWTerm              clrb
                    andcc     #^Carry
                    rts

                    use       boot_common.asm

* Entry: B,X = 24-bit RBF LSN; blockloc,U = destination.
* At this stage the boot image still runs in the initial identity mapping,
* so blockloc is also the physical DMA address.
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
                    clr       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    lda       hwlba,u
                    sta       >FM11_MDC_DATA
                    lda       hwlba+1,u
                    sta       >FM11_MDC_DATA
                    lda       hwlba+2,u
                    sta       >FM11_MDC_DATA
                    lda       #1
                    sta       >FM11_MDC_DATA
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
