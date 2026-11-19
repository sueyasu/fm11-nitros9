********************************************************************
* Boot - FM-11 Level 2 2HD floppy boot module
*
* Loads OS9Boot from a 2HD RBF floppy in standard-FDC drive 0.
* Cylinder 0 is reserved for the ROM IPL and REL/Boot/Krn image.
* RBF logical LSN0 therefore begins at physical T1/H0/S1.
********************************************************************

                    nam       Boot
                    ttl       FM-11 Level 2 2HD floppy Boot module

                    ifp1
                    use       defsfile
                    endc

SectorsPerSide      equ       26
SectorsPerCyl       equ       52
TotalSectors        equ       77*SectorsPerCyl
BootReserveSectors  equ       52
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
CurCylinder         rmb       1                   $FF = unknown physical position
size                equ       .

name                fcs       /Boot/
                    fcb       edition

LSN24BIT            equ       0
FLOPPY              equ       1
FM11BootSeek        equ       1                   check all HWRead failures

HWInit              lda       >FM11_DMA1_MODE
                    anda      #^FM11_DMA_ENABLE
                    sta       >FM11_DMA1_MODE
                    clr       >FM11_FDC_DRIVE
                    lda       #$FF
                    sta       CurCylinder,u
                    clrb
                    andcc     #^Carry
                    rts

HWTerm              clrb
                    andcc     #^Carry
                    rts

                    use       boot_common.asm

********************************************************************
* HWRead - read one RBF-visible 256-byte sector through the standard FDC.
********************************************************************
HWRead              cmpx      #RbfSectors
                    lbhs      HWSectorError
                    leax      BootReserveSectors,x

                    clra
HWCalcCyl           cmpx      #SectorsPerCyl
                    blo       HWGotCyl
                    leax      -SectorsPerCyl,x
                    inca
                    bra       HWCalcCyl
HWGotCyl            lbsr      HWSeek
                    bcs       HWReadError
                    cmpx      #SectorsPerSide
                    blo       HWSide0
                    leax      -SectorsPerSide,x
                    ldb       #1
                    bra       HWGotSide
HWSide0             clrb
HWGotSide           stb       >FM11_FDC_SIDE
                    tfr       x,d
                    incb
                    stb       >FM11_FDC_SECTOR
                    clr       >FM11_FDC_DRIVE

                    pshs      cc
                    orcc      #IntMasks
                    ldx       blockloc,u
                    bsr       SetupDMA1
                    lda       #FM11_FDC_READSEC
                    sta       >FM11_FDC_CMD
                    puls      cc

                    bsr       DMA1Wait
                    bcs       HWReadError
                    lbsr      HWWaitFDC
                    bcs       HWReadError
                    bita      #FM11_FDC_ERRMASK
                    bne       HWReadError

                    ldx       blockloc,u
                    clrb
                    andcc     #^Carry
                    rts

HWReadError         lda       #$FF
                    sta       CurCylinder,u
                    clr       >FM11_DMA1_MODE
                    orcc      #Carry
                    ldb       #E$Read
                    rts

********************************************************************
* SetupDMA1 - map a Level 2 logical buffer address to DMA1 physical.
********************************************************************
SetupDMA1           tfr       x,d
                    stb       >FM11_DMA1_ADDR_L
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
                    sta       >FM11_DMA1_ADDR_H
                    andb      #$0F
                    lslb
                    lslb
                    lslb
                    lslb
                    puls      a
                    anda      #$0F
                    pshs      b
                    ora       ,s+
                    sta       >FM11_DMA1_ADDR_M

                    lda       #1
                    sta       >FM11_DMA1_COUNT_H
                    clr       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA1_MODE
                    rts

DMA1Wait            ldx       #$FFFF
DMA1WaitLoop        lda       >FM11_DMA1_MODE
                    bita      #FM11_DMA_ERROR
                    bne       DMA1WaitError
                    bita      #FM11_DMA_DONE
                    bne       DMA1WaitDone
                    leax      -1,x
                    bne       DMA1WaitLoop
DMA1WaitError       orcc      #Carry
                    rts
DMA1WaitDone        andcc     #^Carry
                    rts

HWSectorError       orcc      #Carry
                    ldb       #E$Sect
                    rts


********************************************************************
* HWSeek - A = target cylinder; preserve X (sector within cylinder)
* and U/Y (boot_common ABI).  First access establishes track zero
* physically; subsequent accesses seek only when the cylinder changes.
* Verify is deliberately disabled ($0B/$1B).
********************************************************************
HWSeek              pshs      a,x
                    clr       >FM11_DMA1_MODE
                    clr       >FM11_FDC_DRIVE
                    bsr       HWWaitFDC
                    bcs       HWSeekFail
                    lda       CurCylinder,u
                    bpl       HWSeekKnown
                    lda       #FM11_FDC_RESTORE_NOVERIFY
                    bsr       HWType1
                    bcs       HWSeekFail
                    clra
                    sta       CurCylinder,u
HWSeekKnown         sta       >FM11_FDC_TRACK
                    cmpa      ,s
                    beq       HWSeekDone
                    lda       ,s
                    sta       >FM11_FDC_DATA
                    lda       #FM11_FDC_SEEK
                    bsr       HWType1
                    bcs       HWSeekFail
                    lda       ,s
                    sta       CurCylinder,u
HWSeekDone          andcc     #^Carry
                    puls      a,x,pc
HWSeekFail          orcc      #Carry
                    puls      a,x,pc

* Type I operations do not use DMA. Allow BUSY to assert, then wait
* for completion before inspecting Type I status.
HWType1             sta       >FM11_FDC_CMD
                    ldb       #16
HWType1Delay        decb
                    bne       HWType1Delay
                    bsr       HWWaitFDC
                    bcs       HWType1Done
                    bita      #FM11_FDC_TYPE1ERR
                    beq       HWType1Done
                    orcc      #Carry
HWType1Done         rts

* Bounded BUSY wait, including worst-case full-stroke seeks.
* Return A = final status, carry set only on timeout.
HWWaitFDC           ldb       #8
HWWaitOuter         ldx       #0
HWWaitBusy          lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_BUSY
                    beq       HWWaitDone
                    leax      -1,x
                    bne       HWWaitBusy
                    decb
                    bne       HWWaitOuter
                    orcc      #Carry
                    rts
HWWaitDone          andcc     #^Carry
                    rts

Address             fdb       FM11_FDC_CMD

                    emod
eom                 equ       *
                    end
