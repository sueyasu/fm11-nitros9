********************************************************************
* Boot - FM-11 Level 2 2D floppy boot module
*
* This is deliberately separate from the Level 1 FM-11 source.  It uses
* the common NitrOS-9 boot_common implementation with the FM-11 2D
* MiniFDC DMA0 backend.
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

                    pshs      cc
                    orcc      #IntMasks
                    ldx       blockloc,u
                    bsr       SetupDMA0
                    lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD
                    puls      cc

                    bsr       DMA0Wait
                    bcs       HWReadError
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       HWReadError

                    ldx       blockloc,u
                    clrb
                    andcc     #^Carry
                    rts

HWReadError         orcc      #Carry
                    ldb       #E$Read
                    rts

********************************************************************
* SetupDMA0 - map a Level 2 logical buffer address to DMA0 physical.
********************************************************************
SetupDMA0           tfr       x,d
                    stb       >FM11_DMA0_ADDR_L
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
                    sta       >FM11_DMA0_ADDR_H
                    andb      #$0F
                    lslb
                    lslb
                    lslb
                    lslb
                    puls      a
                    anda      #$0F
                    pshs      b
                    ora       ,s+
                    sta       >FM11_DMA0_ADDR_M

                    lda       #1
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA0_MODE
                    rts

DMA0Wait            ldx       #$FFFF
DMA0WaitLoop        lda       >FM11_DMA0_MODE
                    bita      #FM11_DMA_ERROR
                    bne       DMA0WaitError
                    bita      #FM11_DMA_DONE
                    bne       DMA0WaitDone
                    leax      -1,x
                    bne       DMA0WaitLoop
DMA0WaitError       orcc      #Carry
                    rts
DMA0WaitDone        andcc     #^Carry
                    rts

HWSectorError       orcc      #Carry
                    ldb       #E$Sect
                    rts

Address             fdb       FM11_MFDC_CMD

                    emod
eom                 equ       *
                    end
