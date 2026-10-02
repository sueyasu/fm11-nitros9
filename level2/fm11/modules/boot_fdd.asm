********************************************************************
* Boot - FM-11 Level 2 2D floppy boot module
*
* This is deliberately separate from the Level 1 FM-11 source.  It uses
* the common NitrOS-9 boot_common implementation with the FM-11 2D
* MiniFDC PIO backend.
********************************************************************

                    nam       Boot
                    ttl       FM-11 Level 2 floppy Boot module

                    ifp1
                    use       defsfile
                    endc

SectorsPerSide      equ       16
SectorsPerCyl       equ       32
TotalSectors        equ       40*SectorsPerCyl
BootReserveSectors  equ       32
RbfSectors          equ       TotalSectors-BootReserveSectors

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

LSN24BIT            equ       0
FLOPPY              equ       1

HWInit              lda       >FM11_DMA0_MODE
                    anda      #^FM11_DMA_ENABLE
                    sta       >FM11_DMA0_MODE
                    clr       >FM11_MFDC_DRIVE
                    clrb
                    andcc     #^Carry
                    rts

HWTerm              clrb
                    andcc     #^Carry
                    rts

                    use       boot_common.asm

HWRead              cmpx      #RbfSectors
                    lbhs      HWSectorError
                    leax      BootReserveSectors,x

                    clra
HWCalcCyl           cmpx      #SectorsPerCyl
                    blo       HWGotCyl
                    leax      -SectorsPerCyl,x
                    inca
                    bra       HWCalcCyl
HWGotCyl            sta       >FM11_MFDC_TRACK
                    cmpx      #SectorsPerSide
                    blo       HWSide0
                    leax      -SectorsPerSide,x
                    ldb       #1
                    bra       HWGotSide
HWSide0             clrb
HWGotSide           stb       >FM11_MFDC_SIDE
                    tfr       x,d
                    incb
                    stb       >FM11_MFDC_SECTOR
                    clr       >FM11_MFDC_DRIVE

                    lda       >FM11_DMA0_MODE
                    anda      #^FM11_DMA_ENABLE
                    sta       >FM11_DMA0_MODE

                    lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD

                    ldx       blockloc,u
                    pshs      y,u
                    ldy       #256
HWReadByte          ldu       #0
HWWaitDRQ           lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       HWReadErrorSaved
                    bita      #FM11_MFDC_DRQ
                    bne       HWHavByte
                    leau      -1,u
                    cmpu      #0
                    bne       HWWaitDRQ
                    bra       HWReadErrorSaved
HWHavByte           lda       >FM11_MFDC_DATA
                    sta       ,x+
                    leay      -1,y
                    bne       HWReadByte

                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       HWReadErrorSaved

                    puls      y,u
                    ldx       blockloc,u
                    clrb
                    andcc     #^Carry
                    rts

HWReadErrorSaved    puls      y,u
                    orcc      #Carry
                    ldb       #E$Read
                    rts

HWSectorError       orcc      #Carry
                    ldb       #E$Sect
                    rts

Address             fdb       FM11_MFDC_CMD

                    emod
eom                 equ       *
                    end
