********************************************************************
* FM-11 2D ROM IPL for NitrOS-9 Level 2
*
* The FM-11 ROM loads T0/H0/S1-S2 (512 bytes) at $0400 and jumps to
* $0400.  S3-S4 remain reserved.  The Level 2 kernel track begins at S5
* and is 18 x 256-byte sectors ($1200).
********************************************************************

                    org       $0400

FDC_CMD             equ       $FD18
FDC_TRACK           equ       $FD19
FDC_SECTOR          equ       $FD1A
FDC_DATA            equ       $FD1B
FDC_SIDE            equ       $FD1C
FDC_DRIVE           equ       $FD1D
DMA0_MODE           equ       $FD50

FDC_READSEC         equ       $80
FDC_DRQ             equ       $02
FDC_ERRMASK         equ       $90
DMA_ENABLE          equ       $04

BOOT_DEST           equ       $2600
BOOT_ENTRY          equ       $2602
BOOT_SECTORS        equ       18

start               bra       main
                    fcb       0,0,0,0,0,0,0,0,0,0,0

main                orcc      #$50
                    lds       #$3F00
                    clr       >FDC_DRIVE

                    lda       >DMA0_MODE
                    anda      #^DMA_ENABLE
                    sta       >DMA0_MODE

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

read_sector         lda       #FDC_READSEC
                    sta       >FDC_CMD
                    ldu       #256
read_byte           pshs      u
                    ldu       #0
wait_drq            lda       >FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail_saved
                    bita      #FDC_DRQ
                    bne       have_byte
                    leau      -1,u
                    cmpu      #0
                    bne       wait_drq
                    puls      u
                    orcc      #$01
                    rts
read_fail_saved     puls      u
                    orcc      #$01
                    rts
have_byte           lda       >FDC_DATA
                    sta       ,x+
                    puls      u
                    leau      -1,u
                    cmpu      #0
                    bne       read_byte
                    lda       >FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    andcc     #$FE
                    rts
read_fail           orcc      #$01
                    rts
boot_error          bra       boot_error

                    end       start
