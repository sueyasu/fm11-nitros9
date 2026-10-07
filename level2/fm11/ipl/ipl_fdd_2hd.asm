********************************************************************
* FM-11 2HD ROM IPL for NitrOS-9 Level 2
*
* The FM-11 1MB-FDD bootstrap loads T0/H0/S1-S4 as four native
* 128-byte FM sectors (512 bytes total) at $0400 and jumps to $0400.
* This IPL loads the 21-sector Level 2 REL/Boot/Krn image from
* T0/H1/S1-S21 (256-byte MFM) to $2600 and jumps to $2602.
* The complete cylinder 0 is reserved from RBF.
********************************************************************

                    org       $0400

FM11_FDC_CMD        equ       $FD30
FM11_FDC_TRACK      equ       $FD31
FM11_FDC_SECTOR     equ       $FD32
FM11_FDC_DATA       equ       $FD33
FM11_FDC_SIDE       equ       $FD34
FM11_FDC_DRIVE      equ       $FD35
FM11_DMA1_MODE      equ       $FD51

FDC_READSEC         equ       $80
FDC_DRQ             equ       $02
FDC_ERRMASK         equ       $90
DMA_ENABLE          equ       $04

BOOT_DEST           equ       $2600
BOOT_ENTRY          equ       $2602
BOOT_SECTORS        equ       21

start               bra       main
                    fcb       0,0,0,0,0,0,0,0,0,0,0

main                orcc      #$50
                    lds       #$3F00
                    clr       >FM11_FDC_DRIVE

* Keep the bootstrap independent of DMA state.
                    lda       >FM11_DMA1_MODE
                    anda      #^DMA_ENABLE
                    sta       >FM11_DMA1_MODE

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
