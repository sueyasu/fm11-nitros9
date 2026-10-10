********************************************************************
* Boot - FM-11 Level 2 MDC hard disk Boot module
*
* Physical sectors:
*   0-1   ROM IPL
*   2-22  21-sector Level 2 kernel track
*   23-31 reserved for future boot-area growth
*   32-   RBF filesystem (LSN0 == physical sector 32)
********************************************************************
                    nam       Boot
                    ttl       FM-11 Level 2 MDC hard disk Boot module

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
size                equ       .

name                fcs       /Boot/
                    fcb       edition

LSN24BIT            equ       1
FLOPPY              equ       0

* Re-establish binary sector addressing for the OS9Boot phase.  The IPL also
* selects this mode, but the Boot module must not depend on controller state
* surviving the intervening REL/kernel initialization.
HWInit              lda       #MDCDMA2Select
                    sta       >FM11_MDC_SELECT
                    lda       #FM11_MDC_SETCMASK
                    sta       >FM11_MDC_CMD
                    lda       #MDCBinaryMask
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    lbra      WaitResult

HWTerm              rts

                    use       boot_common.asm

* Entry: B,X = 24-bit RBF LSN; blockloc,U = destination.
* blockloc is a Level 2 logical address.  DMA2 addresses physical memory,
* so translate blockloc through the currently active 4 KiB MMR before each
* sector transfer.
HWRead              pshs      b
                    tfr       x,d
                    addd      #BootReserveSectors
                    tfr       d,x
                    puls      b
                    adcb      #0
                    pshs      b,x

                    ldx       blockloc,u
                    bsr       SetupDMA2

                    lda       #FM11_MDC_READ
                    sta       >FM11_MDC_CMD
                    clr       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    puls      b,x
                    stb       >FM11_MDC_DATA
                    tfr       x,d
                    sta       >FM11_MDC_DATA
                    stb       >FM11_MDC_DATA
                    lda       #1
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA

                    bsr       WaitResult
                    bcs       HWR_Bad
                    lda       >FM11_DMA2_MODE
                    bita      #FM11_DMA_ERROR
                    bne       HWR_Bad
                    bita      #FM11_DMA_DONE
                    beq       HWR_Bad
                    ldx       blockloc,u
                    rts
HWR_Bad             orcc      #Carry
                    ldb       #E$Read
                    rts

********************************************************************
* SetupDMA2
*
* Entry:
*   X = Level 2 logical buffer address
*
* DMA2 sees physical memory, not the CPU logical address.  Translate X
* through the active FM-11 4 KiB MMR.  This is the read-only boot-time
* equivalent of llfm11hd::SetupDMA2.
********************************************************************
SetupDMA2           tfr       x,d
                    stb       >FM11_DMA2_ADDR_L
                    pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    ldx       #FM11_MMR_BASE
                    lda       a,x
                    tfr       a,b
                    lsra
                    lsra
                    lsra
                    lsra
                    sta       >FM11_DMA2_ADDR_H
                    andb      #$0F
                    lslb
                    lslb
                    lslb
                    lslb
                    puls      a
                    anda      #$0F
                    pshs      b
                    ora       ,s+
                    sta       >FM11_DMA2_ADDR_M

                    lda       #1
                    sta       >FM11_DMA2_COUNT_H
                    clr       >FM11_DMA2_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA2_MODE
                    rts

WaitResult          ldx       #$FFFF
WR_Wait             lda       >FM11_MDC_STATUS
                    bita      #MDCResultReady
                    bne       WR_Ready
                    leax      -1,x
                    bne       WR_Wait
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
