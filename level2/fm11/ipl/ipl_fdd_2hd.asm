********************************************************************
* FM-11 2HD ROM IPL for NitrOS-9 Level 2
*
* The FM-11 1MB-FDD bootstrap loads T0/H0/S1-S4 as four native
* 128-byte FM sectors (512 bytes total) at $0400 and jumps to $0400.
* This IPL loads the 21-sector Level 2 REL/Boot/Krn image from
* T0/H1/S1-S21 (256-byte MFM) to $E000 and jumps to $E002.
* The complete cylinder 0 is reserved from RBF.
********************************************************************

                    org       $0400

FM11_FDC_CMD        equ       $FD30
FM11_FDC_TRACK      equ       $FD31
FM11_FDC_SECTOR     equ       $FD32
FM11_FDC_SIDE       equ       $FD34
FM11_FDC_DRIVE      equ       $FD35
FM11_FDC_IRQ        equ       $FD37
FM11_DMA1_ADDR      equ       $FD44
FM11_DMA1_COUNT     equ       $FD46
FM11_DMA1_MODE      equ       $FD51
FM11_DMA1_BANK      equ       $FD95

FDC_READSEC         equ       $80
FDC_ERRMASK         equ       $9C   * not ready/RNF/CRC/lost data
FDC_DONE            equ       $40
DMA_ENABLE          equ       $04
DMA_DONE            equ       $80
DMA_BOUNCE          equ       $0600
SECTOR_BYTES        equ       256

BOOT_DEST           equ       $E100
BOOT_ENTRY          equ       $E102
BOOT_SECTORS        equ       21

start               bra       main
                    fcb       0,0,0,0,0,0,0,0,0,0,0

main                orcc      #$50
                    lds       #$2500
                    clr       >FM11_FDC_DRIVE

* The 2HD MFM data track runs at 500 kb/s (16 us/byte).
* The 6809 cannot sustain that rate with the old stack-heavy PIO
* polling loop. Use HD6844 DMA to a low-memory bounce buffer, then
* copy the sector to its final high-memory boottrack destination.
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

read_sector         clr       >FM11_DMA1_MODE
                    ldd       #DMA_BOUNCE
                    std       >FM11_DMA1_ADDR
                    ldd       #SECTOR_BYTES
                    std       >FM11_DMA1_COUNT
                    lda       #DMA_ENABLE
                    sta       >FM11_DMA1_MODE
                    lda       #FDC_READSEC
                    sta       >FM11_FDC_CMD

* The FDC signals completion through FD37 bit 6. Allow more than
* one spindle revolution for the sector to arrive before timing out.
                    ldu       #0
wait_irq            lda       >FM11_FDC_IRQ
                    bita      #FDC_DONE
                    bne       irq_done
                    leau      -1,u
                    cmpu      #0
                    bne       wait_irq
                    bra       read_fail
irq_done            lda       >FM11_FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    lda       >FM11_DMA1_MODE
                    bita      #DMA_DONE
                    beq       read_fail

* DMA bank 0 is identity-mapped in the ROM IPL workspace. Copy
* out after the FDC stops requesting bytes; the memory-to-memory
* loop therefore does not need to meet any 16 us DRQ deadline.
                    clr       >FM11_DMA1_MODE
                    ldu       #DMA_BOUNCE
                    clrb
copy_sector         lda       ,u+
                    sta       ,x+
                    decb
                    bne       copy_sector
                    andcc     #$FE
                    rts
read_fail           clr       >FM11_DMA1_MODE
                    orcc      #$01
                    rts
boot_error          bra       boot_error

                    end       start
