********************************************************************
* FM-11 HDD ROM IPL for NitrOS-9 Level 1
*
* FM-11 ROM loads physical HDD sectors 0-1 (512 bytes) at $0400 and
* jumps to $0400.  This IPL loads physical sectors 2-18 (Bootp1.HD,
* 17 x 256 bytes) directly at $EB00 and jumps to $EB02.
********************************************************************
                    org       $0400

* Raw IPL is assembled standalone, so keep the hardware definitions local
* just as the 2D/2HD IPL sources do.
FM11_MDC_CMD        equ       $FDC0
FM11_MDC_STATUS     equ       $FDC0
FM11_MDC_DATA       equ       $FDC1
FM11_MDC_SELECT     equ       $FDC2
FM11_MDC_SETCMASK   equ       $11
FM11_MDC_READ       equ       $22

FM11_DMA2_ADDR_H    equ       $FD96
FM11_DMA2_ADDR_M    equ       $FD48
FM11_DMA2_COUNT_H   equ       $FD4A
FM11_DMA2_COUNT_L   equ       $FD4B
FM11_DMA2_MODE      equ       $FD52
FM11_DMA_ENABLE     equ       $04
FM11_DMA_ERROR      equ       $40
FM11_DMA_DONE       equ       $80
Carry               equ       $01

MDCResultReady      equ       $40
MDCError            equ       $80
MDCBinaryMask       equ       $70
MDCDMA2Select       equ       $20

start               lda       #MDCDMA2Select
                    sta       >FM11_MDC_SELECT
                    lda       #FM11_MDC_SETCMASK
                    sta       >FM11_MDC_CMD
                    lda       #MDCBinaryMask
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    bsr       waitresult
                    bcs       fail
                    lda       #2
                    sta       sector
                    ldx       #$EB00
nextsec             clr       >FM11_DMA2_ADDR_H
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
                    clr       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    lda       sector
                    sta       >FM11_MDC_DATA
                    lda       #1
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    bsr       waitresult
                    bcs       fail
                    lda       >FM11_DMA2_MODE
                    bita      #FM11_DMA_ERROR
                    bne       fail
                    bita      #FM11_DMA_DONE
                    beq       fail
                    inc       sector
                    leax      $0100,x
                    lda       sector
                    cmpa      #19
                    blo       nextsec
                    jmp       $EB02
sector              fcb       2
fail                bra       fail

waitresult          ldy       #$FFFF
wrwait              lda       >FM11_MDC_STATUS
                    bita      #MDCResultReady
                    bne       wrready
                    leay      -1,y
                    bne       wrwait
                    orcc      #Carry
                    rts
wrready             lda       >FM11_MDC_DATA
                    pshs      a
                    ldy       #9
wrdrain             lda       >FM11_MDC_DATA
                    leay      -1,y
                    bne       wrdrain
                    puls      a
                    bita      #MDCError
                    bne       wrbad
                    andcc     #^Carry
                    rts
wrbad               orcc      #Carry
                    rts
                    end
