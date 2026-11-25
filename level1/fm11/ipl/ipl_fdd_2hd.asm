********************************************************************
* FM-11 2HD ROM IPL for NitrOS-9 Level 1
*
* The FM-11 1MB-FDD bootstrap loads T0/H0/S1-S4 as four native
* 128-byte sectors (512 bytes total) at $0400.  This IPL loads the 17-sector NitrOS-9
* boottrack from T0/H1/S1-S17 (256-byte MFM), then jumps
* to $EB02 after loading it directly at $EB00.  The complete cylinder 0 is reserved from RBF.
********************************************************************

                    org       $0400

FM11_FDC_CMD        equ       $FD30
FM11_FDC_TRACK      equ       $FD31
FM11_FDC_SECTOR     equ       $FD32
FM11_FDC_SIDE       equ       $FD34
FM11_FDC_DRIVE      equ       $FD35
FM11_DMA1_ADDR      equ       $FD44
FM11_DMA1_COUNT     equ       $FD46
FM11_DMA1_MODE      equ       $FD51
FM11_DMA1_BANK      equ       $FD95

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

* The 2HD MFM data track runs at 500 kb/s (16 us/byte).
* The boot IPL uses HD6844 DMA to transfer into the final physical
* boottrack address. Bank 0 is identity-mapped before MMU setup.
                    clr       >FM11_DMA1_MODE
                    clr       >FM11_DMA1_BANK

                    clr       >FM11_FDC_TRACK
                    lda       #1
                    sta       >FM11_FDC_SIDE
                    sta       >FM11_FDC_SECTOR
                    ldx       #BOOT_DEST
                    ldy       #BOOT_SECTORS

next_sector         lbsr      read_sector
                    lbcs      boot_error
                    inc       >FM11_FDC_SECTOR
                    leay      -1,y
                    cmpy      #0
                    bne       next_sector
                    jmp       BOOT_ENTRY

* Use HD6844 DMA terminal count rather than the FDC interrupt.
* One physical sector is 256 bytes on the 2HD MFM boottrack.
read_sector         clr       >FM11_DMA1_MODE
                    stx       >FM11_DMA1_ADDR
                    ldd       #256
                    std       >FM11_DMA1_COUNT
                    lda       #DMA_READ_MODE
                    sta       >FM11_DMA1_MODE
                    lda       #FDC_READSEC
                    sta       >FM11_FDC_CMD
                    ldu       #$FFFF
dma_wait            lda       >FM11_DMA1_MODE
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
dma_done            clr       >FM11_DMA1_MODE
                    lda       >FM11_FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    leax      256,x
                    andcc     #$FE
                    rts
read_fail           clr       >FM11_DMA1_MODE
                    orcc      #$01
                    rts
boot_error          bra       boot_error

                    end       start
