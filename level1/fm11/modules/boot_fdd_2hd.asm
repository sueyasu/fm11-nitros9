********************************************************************
* Boot - FM-11 2HD floppy boot module
*
* Loads OS9Boot from an RBF 2HD floppy in drive 0.  The standard
* boot_common code reads LSN0 and follows DD.BT.  v10 uses the
* fragmented-boot form: DD.BSZ=0 and DD.BT points at the file
* descriptor of /OS9Boot.
*
* Hardware path uses DMA1 through the FM-11 standard FDC.
* Geometry is 77 cylinders, 2 sides, 26 sectors per side, 256 bytes per
* sector in the raw boot image.  The complete cylinder 0 (52 sectors)
* is reserved for the ROM IPL and boottrack; RBF LSN0 starts at T1/H0/S1.
********************************************************************

                    nam       Boot
                    ttl       FM-11 2HD floppy Boot module

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

* boot_common static storage.  These names/layouts are required by
* level1/modules/boot_common.asm.
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

* Floppy boot_common configuration.  FM-11 floppy media has fewer than
* 65536 sectors, so only the low 16 bits of LSN are needed.
LSN24BIT            equ       0
FLOPPY              equ       1

* HWInit
*   Y = Address ($FD30, standard 2HD FDC)
* Start with DMA disabled; HWRead programs and enables DMA1 for each sector.
HWInit              lda       >FM11_DMA1_MODE
                    anda      #^FM11_DMA_ENABLE
                    sta       >FM11_DMA1_MODE
                    clr       >FM11_FDC_DRIVE
                    clrb
                    andcc     #^Carry
                    rts

HWTerm              clrb
                    andcc     #^Carry
                    rts

                    use       boot_common.asm

********************************************************************
* HWRead - read one 256-byte sector
*
* Entry from boot_common:
*   X          = low 16 bits of LSN
*   U          = boot static storage
*   Y          = Address; must be preserved across calls
*   blockloc,U = destination buffer
*
* Exit:
*   X = destination buffer
*   C clear on success, B=error and C set on failure
********************************************************************
HWRead              cmpx      #RbfSectors
                    lbhs      HWSectorError
                    leax      BootReserveSectors,x

* Convert physical sector (RBF LSN + reserved boot area) to CHS.
                    clra
HWCalcCyl           cmpx      #SectorsPerCyl
                    blo       HWGotCyl
                    leax      -SectorsPerCyl,x
                    inca
                    bra       HWCalcCyl
HWGotCyl            sta       >FM11_FDC_TRACK
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

* Level 1 uses a flat 16-bit address space, so blockloc is also the DMA
* physical address.  Mask interrupts only while programming DMA/FDC.
                    pshs      cc
                    orcc      #IntMasks
                    ldx       blockloc,u
                    bsr       SetupDMA1
                    lda       #FM11_FDC_READSEC
                    sta       >FM11_FDC_CMD
                    puls      cc

                    bsr       DMA1Wait
                    bcs       HWReadError
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       HWReadError

                    ldx       blockloc,u
                    clrb
                    andcc     #^Carry
                    rts

HWReadError         orcc      #Carry
                    ldb       #E$Read
                    rts

********************************************************************
* SetupDMA1 - program DMA1 for one 256-byte Level 1 transfer.
*
* Entry:
*   X = destination address
*
* Level 1 logical addresses are physical addresses, so no MMR
* translation is required.  The DMA controller has a 20-bit address;
* the upper nibble is zero for the 64 KiB Level 1 address space.
********************************************************************
SetupDMA1           tfr       x,d
                    stb       >FM11_DMA1_ADDR_L
                    sta       >FM11_DMA1_ADDR_M
                    clr       >FM11_DMA1_ADDR_H

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

Address             fdb       FM11_FDC_CMD

                    emod
eom                 equ       *
                    end
