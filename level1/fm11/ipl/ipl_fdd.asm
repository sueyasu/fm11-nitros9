********************************************************************
* FM-11 2D ROM IPL for NitrOS-9 Level 1
*
* BOOT ROM loads only T0/H0/S1-S2 (2 x 256 bytes = 512 bytes) to $0400
* and jumps to $0400.  The current NitrOS-9 disk layout deliberately keeps
* S3-S4 reserved, so the boottrack still begins at S5.  This IPL loads
* 17 boottrack sectors directly to Bt.Start ($EB00) and jumps to $EB02.
********************************************************************

                    org       $0400

FM11_FDC_CMD        equ       $FD18
FM11_FDC_TRACK      equ       $FD19
FM11_FDC_SECTOR     equ       $FD1A
FM11_FDC_SIDE            equ       $FD1C
FM11_FDC_DRIVE           equ       $FD1D
FM11_DMA0_ADDR           equ       $FD40
FM11_DMA0_COUNT          equ       $FD42
FM11_DMA0_MODE           equ       $FD50
FM11_DMA0_BANK           equ       $FD94

FDC_READSEC         equ       $80
FDC_ERRMASK         equ       $9C
DMA_READ_MODE       equ       $04
DMA_ERROR           equ       $40
DMA_COMPLETE        equ       $80

BOOT_DEST           equ       $EB00
BOOT_ENTRY          equ       $EB02
BOOT_SECTORS        equ       17

start               bra       main
                    fcb       0,0,0,0,0,0,0,0,0,0,0

main                orcc      #$50
                    lds       #$3F00
                    clr       >FM11_FDC_DRIVE

* Bank 0 is identity-mapped before the boot image enables the MMU.
* Transfer directly into the final boottrack address via HD6844.
                    clr       >FM11_DMA0_MODE
                    clr       >FM11_DMA0_BANK

                    clr       >FM11_FDC_TRACK
                    clr       >FM11_FDC_SIDE
                    lda       #5
                    sta       >FM11_FDC_SECTOR
                    ldx       #BOOT_DEST
                    ldy       #BOOT_SECTORS

next_sector         lbsr      read_sector
                    lbcs      boot_error
                    inc       >FM11_FDC_SECTOR
                    lda       >FM11_FDC_SECTOR
                    cmpa      #17
                    blo       chs_done
                    lda       #1
                    sta       >FM11_FDC_SECTOR
                    lda       >FM11_FDC_SIDE
                    eora      #1
                    sta       >FM11_FDC_SIDE
chs_done            leay      -1,y
                    cmpy      #0
                    bne       next_sector
                    jmp       BOOT_ENTRY

* Program one physical 256-byte sector, then wait for HD6844
* terminal count. Checking only the FDC interrupt is insufficient:
* the DMA must have delivered every byte before the boot proceeds.
read_sector         clr       >FM11_DMA0_MODE
                    stx       >FM11_DMA0_ADDR
                    ldd       #256
                    std       >FM11_DMA0_COUNT
                    lda       #DMA_READ_MODE
                    sta       >FM11_DMA0_MODE
                    lda       #FDC_READSEC
                    sta       >FM11_FDC_CMD
                    ldu       #$FFFF
dma_wait            lda       >FM11_DMA0_MODE
                    bita      #DMA_ERROR
                    bne       read_fail
                    bita      #DMA_COMPLETE
                    bne       dma_done
                    lda       >FM11_FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    leau      -1,u
                    cmpu      #0
                    bne       dma_wait
                    bra       read_fail
dma_done            clr       >FM11_DMA0_MODE
                    lda       >FM11_FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    leax      256,x
                    andcc     #$FE
                    rts
read_fail           clr       >FM11_DMA0_MODE
                    orcc      #$01
                    rts
boot_error          bra       boot_error

                    end       start
