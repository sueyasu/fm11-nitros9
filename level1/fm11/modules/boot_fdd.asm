********************************************************************
* Boot - FM-11 floppy boot module
*
* Loads OS9Boot from an RBF floppy in drive 0.  The standard
* boot_common code reads LSN0 and follows DD.BT.  v10 uses the
* fragmented-boot form: DD.BSZ=0 and DD.BT points at the file
* descriptor of /OS9Boot.
*
* Hardware path is deliberately PIO through the FM-11 2D MiniFDC.  Geometry is 40 cylinders, 2 sides, 16 sectors
* per side, 256 bytes per sector.  The complete first physical track (32 sectors) is reserved for the ROM
* IPL and boottrack; RBF LSN0 starts at physical sector 32 (T1/H0/S1).
********************************************************************

                    nam       Boot
                    ttl       FM-11 floppy Boot module

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
*   Y = Address ($FD18, 2D MiniFDC)
* Keep the first boot implementation in PIO mode, independent of the RBSuper runtime path.
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

* Force PIO in case firmware or an earlier stage left DMA enabled.
                    lda       >FM11_DMA0_MODE
                    anda      #^FM11_DMA_ENABLE
                    sta       >FM11_DMA0_MODE

                    lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD

* Y must remain the hardware-address value between boot_common calls;
* U must remain the static-storage pointer.  Save both while using them
* as the byte counter and timeout counter.
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

* Final status read completes/acknowledges the PIO operation in
* fm11-headless.
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
