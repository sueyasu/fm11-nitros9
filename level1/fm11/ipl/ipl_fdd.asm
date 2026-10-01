********************************************************************
* FM-11 2D ROM IPL for NitrOS-9 Level 1
*
* BOOT ROM loads only T0/H0/S1-S2 (2 x 256 bytes = 512 bytes) to $0400
* and jumps to $0400.  The current NitrOS-9 disk layout deliberately keeps
* S3-S4 reserved, so the boottrack still begins at S5.  This IPL loads
* 17 boottrack sectors to $2600 and jumps to $2602.
********************************************************************

                    org       $0400

FM11_FDC_CMD        equ       $FD18
FM11_FDC_TRACK      equ       $FD19
FM11_FDC_SECTOR     equ       $FD1A
FM11_FDC_DATA       equ       $FD1B
FM11_FDC_SIDE       equ       $FD1C
FM11_FDC_DRIVE      equ       $FD1D
FM11_DMA0_MODE      equ       $FD50

FDC_READSEC         equ       $80
FDC_DRQ             equ       $02
FDC_ERRMASK         equ       $90
DMA_ENABLE          equ       $04

BOOT_DEST           equ       $2600
BOOT_ENTRY          equ       $2602
BOOT_SECTORS        equ       17

start               bra       main
                    fcb       0,0,0,0,0,0,0,0,0,0,0

main                orcc      #$50
                    lds       #$3F00
                    clr       >FM11_FDC_DRIVE

                    lda       >FM11_DMA0_MODE
                    anda      #^DMA_ENABLE
                    sta       >FM11_DMA0_MODE

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

read_sector         lda       #FDC_READSEC
                    sta       >FM11_FDC_CMD
                    ldu       #256
read_byte           pshs      u
                    ldu       #0
wait_drq            lda       >FM11_FDC_CMD
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
have_byte           lda       >FM11_FDC_DATA
                    sta       ,x+
                    puls      u
                    leau      -1,u
                    cmpu      #0
                    bne       read_byte
                    lda       >FM11_FDC_CMD
                    bita      #FDC_ERRMASK
                    bne       read_fail
                    andcc     #$FE
                    rts
read_fail           orcc      #$01
                    rts
boot_error          bra       boot_error

                    end       start
