********************************************************************
* FM-11 2D ROM IPL for NitrOS-9 Level 2
*
* The FM-11 ROM loads T0/H0/S1-S2 (512 bytes) at $0400 and jumps to
* $0400.  S3-S4 remain reserved.  The Level 2 kernel track begins at S5
* and is loaded directly at $E000.
********************************************************************

                    org       $0400

FDC_CMD             equ       $FD18
FDC_TRACK           equ       $FD19
FDC_SECTOR          equ       $FD1A
FDC_SIDE            equ       $FD1C
FDC_DRIVE           equ       $FD1D
DMA0_ADDR           equ       $FD40
DMA0_COUNT          equ       $FD42
DMA0_MODE           equ       $FD50
DMA0_BANK           equ       $FD94

FDC_READSEC         equ       $80
FDC_ERRMASK         equ       $9C
DMA_READ_MODE       equ       $04
DMA_ERROR           equ       $40
DMA_COMPLETE        equ       $80

BOOT_DEST           equ       $E100
BOOT_ENTRY          equ       $E102
BOOT_SECTORS        equ       21

start               bra       main
                    fcb       0,0,0,0,0,0,0,0,0,0,0

main                orcc      #$50
                    lds       #$2500
                    clr       >FDC_DRIVE

* Bank 0 is identity-mapped before the boot image enables the MMU.
* Transfer directly into the final boottrack address via HD6844.
                    clr       >DMA0_MODE
                    clr       >DMA0_BANK

                    clr       >FDC_TRACK
                    clr       >FDC_SIDE
                    lda       #5
                    sta       >FDC_SECTOR
                    ldx       #BOOT_DEST
                    ldy       #BOOT_SECTORS

next_sector         lbsr      read_sector
                    lbcs      boot_error
                    inc       >FDC_SECTOR
                    lda       >FDC_SECTOR
                    cmpa      #17
                    blo       chs_done
                    lda       #1
                    sta       >FDC_SECTOR
                    lda       >FDC_SIDE
                    eora      #1
                    sta       >FDC_SIDE
chs_done            leay      -1,y
                    cmpy      #0
                    bne       next_sector
                    jmp       BOOT_ENTRY

* Program one physical 256-byte sector, then wait for HD6844
* terminal count. Checking only the FDC interrupt is insufficient:
* the DMA must have delivered every byte before the boot proceeds.
read_sector         clr       >DMA0_MODE
                    stx       >DMA0_ADDR
                    ldd       #256
                    std       >DMA0_COUNT
                    lda       #DMA_READ_MODE
                    sta       >DMA0_MODE
                    lda       #FDC_READSEC
                    sta       >FDC_CMD
                    ldu       #$FFFF
dma_wait            lda       >DMA0_MODE
                    bita      #DMA_ERROR
                    bne       read_fail
                    bita      #DMA_COMPLETE
                    bne       dma_done
                    lda       >FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    leau      -1,u
                    cmpu      #0
                    bne       dma_wait
                    bra       read_fail
dma_done            clr       >DMA0_MODE
                    lda       >FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    leax      256,x
                    andcc     #$FE
                    rts
read_fail           clr       >DMA0_MODE
                    orcc      #$01
                    rts
boot_error          bra       boot_error

                    end       start
