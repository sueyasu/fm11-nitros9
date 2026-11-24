********************************************************************
* llfm11 - FM-11 Level 2 low-level floppy driver for RBSuper
*
* PD.DRV 0/1: 2D MiniFDC + DMA0
* PD.DRV 2/3: 2HD standard FDC + DMA1
*
* RBSuper buffer pointers are Level 2 logical addresses, so every DMA transfer
* translates V.LocalBuf through the active FM-11 4 KiB MMR before programming
* the 20-bit DMA address.
*
* Geometry:
*   2D:  40 cylinders x 2 sides x 16 x 256-byte sectors
*   2HD: 77 cylinders x 2 sides x 26 x 256-byte sectors
* The descriptors hide the boot cylinder from normal RBF access.
********************************************************************

                    nam       llfm11
                    ttl       FM-11 Level 2 DMA floppy driver

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

D2SectorsPerSide    equ       16
D2SectorsPerCyl     equ       32
D2TotalSectors      equ       40*D2SectorsPerCyl

HD2SectorsPerSide   equ       26
HD2SectorsPerCyl    equ       52
HD2TotalSectors     equ       77*HD2SectorsPerCyl
PIOTimeout          equ       0
FM11UseDMA0         equ       1

* SS.WTrk must feed one complete revolution to the FDC without a DMA gap.
* Allocate two contiguous 8 KiB Level 2 physical blocks as a temporary
* 16 KiB bounce area.  2D consumes $1900 bytes; 2HD consumes $2A94 bytes.
WTrkBlocks          equ       2
WTrk2DBytes         equ       $1900
WTrk2HDBytes        equ       $2A94

AssetBlocks         equ       1
IPLAssetBytes       equ       1024
BootAssetBytes      equ       21*256

rev                 set       $00
edition             set       2
tylg                set       Sbrtn+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,start,0

                    org       V.LLMem
V.LocalSect         rmb       3
V.LocalCnt          rmb       1
V.LocalBuf          rmb       2
V.WTrkBlk           rmb       2       ; F$AllRAM physical 8 KiB block
V.WTrkMap           rmb       2       ; temporary process logical mapping
V.WTrkLen           rmb       2       ; bytes copied to the bounce area
V.AssetBlk          rmb       2       ; Cobbler asset physical 8 KiB block
V.AssetMap          rmb       2       ; temporary process logical mapping
V.AssetLen          rmb       2       ; bytes copied to the asset bounce block

V.CylPos            rmb       4                   physical cylinders; $FF unknown

name                fcs       /llfm11/
                    fcb       edition

* RBSuper low-level ABI: six LBRA entry points, exactly three bytes apart.
start               lbra      ll_init
                    lbra      ll_read
                    lbra      ll_write
                    lbra      ll_getstat
                    lbra      ll_setstat
                    lbra      ll_term

ll_init             ldd       #$FFFF
                    std       V.CylPos,u
                    std       V.CylPos+2,u
                    clrb
                    andcc     #^Carry
                    rts

ll_term             clrb
                    andcc     #^Carry
                    rts

********************************************************************
* SetupCHS - convert V.LocalSect to controller cylinder/side/sector.
********************************************************************
SetupCHS            lda       PD.DRV,y
                    cmpa      #2
                    lblo       Setup2D
                    cmpa      #4
                    lblo       Setup2HD
                    lbra       BadUnit

Setup2D
                    tst       V.LocalSect,u
                    lbne       BadSector
                    ldx       V.LocalSect+1,u
                    cmpx      #D2TotalSectors
                    lbhs       BadSector

                    clra
S2Cyl               cmpx      #D2SectorsPerCyl
                    lblo       S2GotCyl
                    leax      -D2SectorsPerCyl,x
                    inca
                    lbra       S2Cyl
S2GotCyl            lbsr      SeekCylinder
                    lbcs      SeekReadError

                    cmpx      #D2SectorsPerSide
                    lblo       S2Side0
                    leax      -D2SectorsPerSide,x
                    ldb       #1
                    lbra       S2GotSide
S2Side0             clrb
S2GotSide           stb       >FM11_MFDC_SIDE
                    tfr       x,d
                    incb
                    stb       >FM11_MFDC_SECTOR
                    lda       PD.DRV,y
                    sta       >FM11_MFDC_DRIVE
                    clrb
                    andcc     #^Carry
                    rts

Setup2HD            tst       V.LocalSect,u
                    lbne       BadSector
                    ldx       V.LocalSect+1,u
                    cmpx      #HD2TotalSectors
                    lbhs       BadSector

                    clra
SHCyl               cmpx      #HD2SectorsPerCyl
                    lblo       SHGotCyl
                    leax      -HD2SectorsPerCyl,x
                    inca
                    lbra       SHCyl
SHGotCyl            lbsr      SeekCylinder
                    lbcs      SeekReadError

                    cmpx      #HD2SectorsPerSide
                    lblo       SHSide0
                    leax      -HD2SectorsPerSide,x
                    ldb       #1
                    lbra       SHGotSide
SHSide0             clrb
SHGotSide           stb       >FM11_FDC_SIDE
                    tfr       x,d
                    incb
                    stb       >FM11_FDC_SECTOR
                    lda       PD.DRV,y
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    clrb
                    andcc     #^Carry
                    rts

BadUnit             orcc      #Carry
                    ldb       #E$Unit
                    rts

BadSector           orcc      #Carry
                    ldb       #E$Sect
                    rts

Advance             inc       V.LocalSect+2,u
                    lbcc       AdvBuf
                    inc       V.LocalSect+1,u
                    lbcc       AdvBuf
                    inc       V.LocalSect,u
AdvBuf              inc       V.LocalBuf,u
                    rts

********************************************************************
* WaitDRQ
*
* Exit: carry clear when DRQ is asserted.
*       carry set/B=E$Read when controller error or timeout occurs.
********************************************************************
                  IFEQ      FM11UseDMA0
WaitDRQ             pshs      x
                    ldx       #PIOTimeout
WaitDRQLoop         lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    lbne      PIOReadError
                    bita      #FM11_MFDC_DRQ
                    lbne       WaitDRQDone
                    leax      -1,x
                    cmpx      #0
                    lbne       WaitDRQLoop
PIOReadError        puls      x
                    orcc      #Carry
                    ldb       #E$Read
                    rts
WaitDRQDone         puls      x
                    clrb
                    andcc     #^Carry
                    rts
                  ELSE
WaitDRQ
PIOReadError        rts
                  ENDC

********************************************************************
* SetupDMA0Address
*
* Input: X = current CPU logical buffer address.
*
* DMA sees physical memory, not the Level 2 logical mapping.  Translate the
* 16-bit CPU address through the currently active 4 KiB FM-11 MMR.
*
*   logical high byte = pppp oooo
*     pppp = MMR slot (0..15)
*     oooo = logical address bits 11..8
*
*   MMR[pppp] = physical 4 KiB page number
*
* DMA address:
*   ADDR_H = physical page bits 7..4
*   ADDR_M = physical page bits 3..0 : logical bits 11..8
*   ADDR_L = logical bits 7..0
********************************************************************
SetupDMA0Address    pshs      d,x,y
                    tfr       x,d
                    stb       >FM11_DMA0_ADDR_L
                    pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    ldy       #FM11_MMR_BASE
                    lda       a,y
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
                    puls      d,x,y,pc

********************************************************************
* SetupDMA1Address - Level 2 logical -> physical address for 2HD DMA.
********************************************************************
SetupDMA1Address    pshs      d,x,y
                    tfr       x,d
                    stb       >FM11_DMA1_ADDR_L
                    pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    ldy       #FM11_MMR_BASE
                    lda       a,y
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
                    puls      d,x,y,pc

********************************************************************
* DMA0Wait - wait for DMA completion or error.
********************************************************************
DMA0Wait            pshs      x
                    ldx       #PIOTimeout
DMA0WaitLoop        lda       >FM11_DMA0_MODE
                    bita      #FM11_DMA_ERROR
                    lbne       DMA0WaitError
                    bita      #FM11_DMA_DONE
                    lbne       DMA0WaitDone
                    leax      -1,x
                    cmpx      #0
                    lbne       DMA0WaitLoop
DMA0WaitError       puls      x
                    orcc      #Carry
                    rts
DMA0WaitDone        puls      x
                    andcc     #^Carry
                    rts

DMA1Wait            pshs      x
                    ldx       #PIOTimeout
DMA1WaitLoop        lda       >FM11_DMA1_MODE
                    bita      #FM11_DMA_ERROR
                    lbne       DMA1WaitError
                    bita      #FM11_DMA_DONE
                    lbne       DMA1WaitDone
                    leax      -1,x
                    cmpx      #0
                    lbne       DMA1WaitLoop
DMA1WaitError       puls      x
                    orcc      #Carry
                    rts
DMA1WaitDone        puls      x
                    andcc     #^Carry
                    rts

********************************************************************
* ReadSector / WriteSector.
*
* DMA mode performs one 256-byte transfer per physical sector.  V.LocalBuf is
* translated again after every Advance, so a 4 KiB boundary is safe even when
* adjacent logical pages map to non-contiguous physical pages.
********************************************************************
ReadSector
                    lda       PD.DRV,y
                    cmpa      #2
                    lbhs      ReadSector2HD
                  IFNE      FM11UseDMA0
                    lbra      ReadSectorDMA
                  ELSE
                    lbra      ReadSectorPIO
                  ENDC

ReadSectorDMA       pshs      cc
                    orcc      #IntMasks
                    ldx       V.LocalBuf,u
                    lbsr      SetupDMA0Address
                    lda       #1
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA0_MODE
                    lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD
                    puls      cc
                    lbsr      DMA0Wait
                    lbcs       DMAReadError
                    lbsr      WaitMiniFDC
                    lbcs      DMAReadError
                    bita      #FM11_MFDC_ERRMASK
                    lbne      DMAReadError
                    clrb
                    andcc     #^Carry
                    rts
DMAReadError        lbsr      DiskIOFailed
                    orcc      #Carry
                    ldb       #E$Read
                    rts

ReadSector2HD       cmpa      #4
                    lbhs      BadUnit
                    pshs      cc
                    orcc      #IntMasks
                    ldx       V.LocalBuf,u
                    lbsr      SetupDMA1Address
                    lda       #1
                    sta       >FM11_DMA1_COUNT_H
                    clr       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA1_MODE
                    lda       #FM11_FDC_READSEC
                    sta       >FM11_FDC_CMD
                    puls      cc
                    lbsr      DMA1Wait
                    lbcs       DMAReadError
                    lbsr      WaitStdFDC
                    lbcs      DMAReadError
                    bita      #FM11_FDC_ERRMASK
                    lbne      DMAReadError
                    clrb
                    andcc     #^Carry
                    rts

ReadSectorPIO       pshs      y
                    lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD
                    ldx       V.LocalBuf,u
                    ldy       #256
ReadByte            lbsr      WaitDRQ
                    lbcs       ReadDone
                    lda       >FM11_MFDC_DATA
                    sta       ,x+
                    leay      -1,y
                    lbne       ReadByte
                    lbsr      WaitMiniFDC
                    lbcs       ReadPIOFail
                    bita      #FM11_MFDC_ERRMASK
                    lbne       ReadPIOFail
                    clrb
                    andcc     #^Carry
                    lbra       ReadDone
ReadPIOFail         ldb       #E$Read
                    orcc      #Carry
ReadDone            puls      y
                    lbcc       ReadPIORet
                    lbsr      DiskIOFailed
ReadPIORet          rts

WaitWriteDRQ        pshs      x
                    ldx       #PIOTimeout
WaitWriteLoop       lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    lbne       PIOWriteError
                    bita      #FM11_MFDC_DRQ
                    lbne       WaitWriteDone
                    leax      -1,x
                    cmpx      #0
                    lbne       WaitWriteLoop
PIOWriteError       puls      x
                    orcc      #Carry
                    ldb       #E$Write
                    rts
WaitWriteDone       puls      x
                    clrb
                    andcc     #^Carry
                    rts

WriteSector
                    lda       PD.DRV,y
                    cmpa      #2
                    lbhs      WriteSector2HD
                  IFNE      FM11UseDMA0
                    lbra      WriteSectorDMA
                  ELSE
                    lbra      WriteSectorPIO
                  ENDC

WriteSectorDMA      pshs      cc
                    orcc      #IntMasks
                    ldx       V.LocalBuf,u
                    lbsr      SetupDMA0Address
                    lda       #1
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA0_MODE
                    lda       #FM11_MFDC_WRITESEC
                    sta       >FM11_MFDC_CMD
                    puls      cc
                    lbsr      DMA0Wait
                    lbcs       DMAWriteError
                    lbsr      WaitMiniFDC
                    lbcs      DMAWriteError
                    bita      #FM11_MFDC_ERRMASK
                    lbne      DMAWriteError
                    clrb
                    andcc     #^Carry
                    rts
DMAWriteError       lbsr      DiskIOFailed
                    orcc      #Carry
                    ldb       #E$Write
                    rts

WriteSector2HD      cmpa      #4
                    lbhs      BadUnit
                    pshs      cc
                    orcc      #IntMasks
                    ldx       V.LocalBuf,u
                    lbsr      SetupDMA1Address
                    lda       #1
                    sta       >FM11_DMA1_COUNT_H
                    clr       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA1_MODE
                    lda       #FM11_FDC_WRITESEC
                    sta       >FM11_FDC_CMD
                    puls      cc
                    lbsr      DMA1Wait
                    lbcs       DMAWriteError
                    lbsr      WaitStdFDC
                    lbcs      DMAWriteError
                    bita      #FM11_FDC_ERRMASK
                    lbne      DMAWriteError
                    clrb
                    andcc     #^Carry
                    rts

WriteSectorPIO      pshs      y
                    lda       #FM11_MFDC_WRITESEC
                    sta       >FM11_MFDC_CMD
                    ldx       V.LocalBuf,u
                    ldy       #256
WriteByte           lbsr      WaitWriteDRQ
                    lbcs       WriteDone
                    lda       ,x+
                    sta       >FM11_MFDC_DATA
                    leay      -1,y
                    lbne       WriteByte
                    lbsr      WaitMiniFDC
                    lbcs       WritePIOFail
                    bita      #FM11_MFDC_ERRMASK
                    lbne       WritePIOFail
                    clrb
                    andcc     #^Carry
                    lbra       WriteDone
WritePIOFail        ldb       #E$Write
                    orcc      #Carry
WriteDone           puls      y
                    lbcc       WritePIORet
                    lbsr      DiskIOFailed
WritePIORet         rts

********************************************************************
* RBSuper read/write entry points.
********************************************************************
ll_read             lda       V.PhysSect,u
                    ldx       V.PhysSect+1,u
                    sta       V.LocalSect,u
                    stx       V.LocalSect+1,u
                    lda       V.SectCnt,u
                    sta       V.LocalCnt,u
                    ldx       V.CchPSpot,u
                    stx       V.LocalBuf,u

ReadLoop            lbsr      SetupCHS
                    lbcs       ReadExit
                    lbsr      ReadSector
                    lbcs       ReadExit
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    lbne       ReadLoop
                    clrb
                    andcc     #^Carry
ReadExit            rts

ll_write            lda       V.PhysSect,u
                    ldx       V.PhysSect+1,u
                    sta       V.LocalSect,u
                    stx       V.LocalSect+1,u
                    lda       V.SectCnt,u
                    sta       V.LocalCnt,u
                    ldx       V.CchPSpot,u
                    stx       V.LocalBuf,u

WriteLoop           lbsr      SetupCHS
                    lbcs       WriteExit
                    lbsr      WriteSector
                    lbcs       WriteExit
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    lbne       WriteLoop
                    clrb
                    andcc     #^Carry
WriteExit           rts

********************************************************************
* Minimal GetStat/SetStat needed for normal RBF operation.
********************************************************************
ll_getstat          ldx       PD.RGS,y
                    lda       R$B,x
                    cmpa      #SS.DSize
                    lbne      UnknownSvc
                    lda       #1
                    sta       R$A,x
                    clr       R$B,x
                    clra
                    clrb
                    std       R$X,x
                    lda       PD.DRV,y
                    cmpa      #2
                    lbhs       GetSize2HD
                    ldd       #D2TotalSectors
                    lbra       GetSizeDone
GetSize2HD          cmpa      #4
                    lbhs      BadUnit
                    ldd       #HD2TotalSectors
GetSizeDone
                    std       R$Y,x
                    clrb
                    andcc     #^Carry
                    rts

ll_setstat          ldx       PD.RGS,y
                    lda       R$B,x
                    cmpa      #SS.SQD
                    lbeq       StatOK
                    cmpa      #SS.Reset
                    lbeq       ll_reset
                    cmpa      #SS.WTrk
                    lbeq      ll_writetrack
                    cmpa      #SS.FM11Boot
                    lbeq      ll_boottrack
                    cmpa      #SS.FM11IPL
                    lbeq      ll_ipl
                    lbra      UnknownSvc

ll_reset            lbsr      InvalidateCylinder
                    clra
                    lbsr      SeekCylinder
                    lbcs      SeekWriteError
StatOK              clrb
                    andcc     #^Carry
                    rts

********************************************************************
* SS.FM11IPL - write the reserved ROM IPL sectors on cylinder 0.
*
* R$X belongs to the Cobbler process.  Do not DMA from that logical address
* directly: the low-level driver may execute while another hardware MMR map is
* active.  Copy the complete IPL image into one F$AllRAM 8 KiB block, remove
* the temporary process mapping, then DMA from the physical block directly.
********************************************************************
ll_ipl              ldd       #IPLAssetBytes
                    lbsr      AssetPrepare
                    lbcs       LIPLExit
                    lda       #4
                    sta       V.LocalCnt,u
                    lda       PD.DRV,y
                    cmpa      #2
                    lbhs       LIPL2HD

LIPL2D              sta       >FM11_MFDC_DRIVE
                    clra
                    lbsr      SeekCylinder
                    lbcs      LIPLIOExit
                    clr       >FM11_MFDC_SIDE
                    lda       #1
                    sta       >FM11_MFDC_SECTOR
LIPL2DLoop          lbsr      WriteAsset2D256
                    lbcs       LIPLIOExit
                    inc       V.LocalBuf,u
                    inc       >FM11_MFDC_SECTOR
                    dec       V.LocalCnt,u
                    lbne       LIPL2DLoop
                    lbsr      AssetFreeRAM
                    lbra      StatOK

LIPL2HD             cmpa      #4
                    lbhs       LIPLBadUnit
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    clra
                    lbsr      SeekCylinder
                    lbcs      LIPLIOExit
                    clr       >FM11_FDC_SIDE
                    lda       #1
                    sta       >FM11_FDC_SECTOR
LIPL2HDLoop         lbsr      WriteAsset2HD128
                    lbcs       LIPLIOExit
                    ldd       V.LocalBuf,u
                    addd      #$0080
                    std       V.LocalBuf,u
                    inc       >FM11_FDC_SECTOR
                    dec       V.LocalCnt,u
                    lbne       LIPL2HDLoop
                    lbsr      AssetFreeRAM
                    lbra      StatOK

LIPLBadUnit         ldb       #E$Unit
                    lbra       LIPLIOExit
LIPLIOExit          pshs      b
                    lbsr      AssetFreeRAM
                    puls      b
                    orcc      #Carry
LIPLExit            rts

********************************************************************
* SS.FM11Boot - write the 21-sector Level 2 REL/Boot/Krn kernel track.
*
* 2D:
*   T0/H0/S5-S16 (12 sectors), then T0/H1/S1-S9 (9 sectors)
* 2HD:
*   T0/H1/S1-S21
********************************************************************
ll_boottrack        ldd       #BootAssetBytes
                    lbsr      AssetPrepare
                    lbcs       LBTExit
                    lda       #21
                    sta       V.LocalCnt,u
                    lda       PD.DRV,y
                    cmpa      #2
                    lbhs       LBT2HD

LBT2D               sta       >FM11_MFDC_DRIVE
                    clra
                    lbsr      SeekCylinder
                    lbcs      LBTIOExit
                    clr       >FM11_MFDC_SIDE
                    lda       #5
                    sta       >FM11_MFDC_SECTOR
LBT2DLoop           lbsr      WriteAsset2D256
                    lbcs       LBTIOExit
                    inc       V.LocalBuf,u
                    inc       >FM11_MFDC_SECTOR
                    lda       >FM11_MFDC_SECTOR
                    cmpa      #17
                    lblo       LBT2DNext
                    lda       #1
                    sta       >FM11_MFDC_SECTOR
                    lda       >FM11_MFDC_SIDE
                    eora      #1
                    sta       >FM11_MFDC_SIDE
LBT2DNext           dec       V.LocalCnt,u
                    lbne       LBT2DLoop
                    lbsr      AssetFreeRAM
                    lbra      StatOK

LBT2HD              cmpa      #4
                    lbhs       LBTBadUnit
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    clra
                    lbsr      SeekCylinder
                    lbcs      LBTIOExit
                    lda       #1
                    sta       >FM11_FDC_SIDE
                    lda       #1
                    sta       >FM11_FDC_SECTOR
LBT2HDLoop          lbsr      WriteAsset2HD256
                    lbcs       LBTIOExit
                    inc       V.LocalBuf,u
                    inc       >FM11_FDC_SECTOR
                    dec       V.LocalCnt,u
                    lbne       LBT2HDLoop
                    lbsr      AssetFreeRAM
                    lbra      StatOK

LBTBadUnit          ldb       #E$Unit
                    lbra       LBTIOExit
LBTIOExit           pshs      b
                    lbsr      AssetFreeRAM
                    puls      b
                    orcc      #Carry
LBTExit             rts

********************************************************************
* AssetPrepare
*
* Entry: D = byte count to copy from caller R$X.
* Exit:  V.AssetBlk = one physical 8 KiB block containing the asset,
*        V.LocalBuf = zero byte offset into that block.
*
* The temporary logical mapping is removed before DMA starts.  All following
* DMA address calculations therefore use V.AssetBlk directly and are
* independent of the currently selected FM-11 hardware task map.
********************************************************************
AssetPrepare        std       V.AssetLen,u
                    ldb       #AssetBlocks
                    os9       F$AllRAM
                    lbcs       AssetAllocFail
                    std       V.AssetBlk,u

                    tfr       d,x
                    ldb       #AssetBlocks
                    pshs      y,u
                    os9       F$MapBlk
                    lbcs       AssetMapFailStack
                    tfr       u,d
                    puls      y,u
                    std       V.AssetMap,u

                    pshs      y,u
                    ldx       PD.RGS,y
                    ldx       R$X,x
                    pshs      x
                    ldx       <D.Proc
                    lda       P$Task,x
                    tfr       a,b
                    puls      x
                    ldy       V.AssetLen,u
                    ldu       V.AssetMap,u
                    os9       F$Move
                    puls      y,u
                    lbcs       AssetMoveFail

                    pshs      y,u
                    ldb       #AssetBlocks
                    ldu       V.AssetMap,u
                    os9       F$ClrBlk
                    puls      y,u
                    lbcs       AssetUnmapFail

                    clra
                    clrb
                    std       V.LocalBuf,u
                    andcc     #^Carry
                    rts

AssetMapFailStack   puls      y,u
                    pshs      b
                    lbsr      AssetFreeRAM
                    puls      b
                    orcc      #Carry
                    rts

AssetMoveFail       pshs      b
                    lbsr      AssetReleaseMapped
                    puls      b
                    orcc      #Carry
                    rts

* As with SS.WTrk, do not free RAM if F$ClrBlk failed: the block may still be
* present in the process DAT image.
AssetUnmapFail      orcc      #Carry
                    rts
AssetAllocFail      orcc      #Carry
                    rts

AssetReleaseMapped  pshs      y,u
                    ldb       #AssetBlocks
                    ldu       V.AssetMap,u
                    os9       F$ClrBlk
                    puls      y,u
                    lbcs       AssetReleaseDone
                    lbsr      AssetFreeRAM
AssetReleaseDone    rts

AssetFreeRAM        pshs      y,u
                    ldx       V.AssetBlk,u
                    ldb       #AssetBlocks
                    os9       F$DelRAM
                    puls      y,u
                    rts

********************************************************************
* Physical DMA address for the one-block asset bounce buffer.
*
* One Level 2 physical block is 8 KiB.  With block number B:
*   address[19:16] = B >> 3
*   address[15:8]  = ((B & 7) << 5) + offset[12:8]
*   address[7:0]   = offset[7:0]
* V.LocalBuf is used as a byte offset within the block.
********************************************************************
SetupAssetDMA0      lda       V.AssetBlk+1,u
                    pshs      a
                    lsra
                    lsra
                    lsra
                    sta       >FM11_DMA0_ADDR_H
                    puls      a
                    anda      #$07
                    lsla
                    lsla
                    lsla
                    lsla
                    lsla
                    adda      V.LocalBuf,u
                    sta       >FM11_DMA0_ADDR_M
                    lda       V.LocalBuf+1,u
                    sta       >FM11_DMA0_ADDR_L
                    rts

SetupAssetDMA1      lda       V.AssetBlk+1,u
                    pshs      a
                    lsra
                    lsra
                    lsra
                    sta       >FM11_DMA1_ADDR_H
                    puls      a
                    anda      #$07
                    lsla
                    lsla
                    lsla
                    lsla
                    lsla
                    adda      V.LocalBuf,u
                    sta       >FM11_DMA1_ADDR_M
                    lda       V.LocalBuf+1,u
                    sta       >FM11_DMA1_ADDR_L
                    rts

WriteAsset2D256     pshs      cc
                    orcc      #IntMasks
                    lbsr      SetupAssetDMA0
                    lda       #1
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA0_MODE
                    lda       #FM11_MFDC_WRITESEC
                    sta       >FM11_MFDC_CMD
                    puls      cc
                    lbsr      DMA0Wait
                    lbcs       WriteAssetError
                    lbsr      WaitMiniFDC
                    lbcs      WriteAssetError
                    bita      #FM11_MFDC_ERRMASK
                    lbne      WriteAssetError
                    clrb
                    andcc     #^Carry
                    rts

WriteAsset2HD256    pshs      cc
                    orcc      #IntMasks
                    lbsr      SetupAssetDMA1
                    lda       #1
                    sta       >FM11_DMA1_COUNT_H
                    clr       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA1_MODE
                    lda       #FM11_FDC_WRITESEC
                    sta       >FM11_FDC_CMD
                    puls      cc
                    lbsr      DMA1Wait
                    lbcs       WriteAssetError
                    lbsr      WaitStdFDC
                    lbcs      WriteAssetError
                    bita      #FM11_FDC_ERRMASK
                    lbne      WriteAssetError
                    clrb
                    andcc     #^Carry
                    rts

WriteAsset2HD128    pshs      cc
                    orcc      #IntMasks
                    lbsr      SetupAssetDMA1
                    clr       >FM11_DMA1_COUNT_H
                    lda       #$80
                    sta       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA1_MODE
                    lda       #FM11_FDC_WRITESEC
                    sta       >FM11_FDC_CMD
                    puls      cc
                    lbsr      DMA1Wait
                    lbcs       WriteAssetError
                    lbsr      WaitStdFDC
                    lbcs      WriteAssetError
                    bita      #FM11_FDC_ERRMASK
                    lbne      WriteAssetError
                    clrb
                    andcc     #^Carry
                    rts

WriteAssetError     lbsr      DiskIOFailed
                    orcc      #Carry
                    ldb       #E$Write
                    rts

********************************************************************
* SS.WTrk - write one complete format track using a physically contiguous
* 16 KiB bounce area.
*
* FORMAT register convention:
*   R$X = address of Write Track image in the caller
*   R$U = physical track number
*   R$Y low byte bit 0 = side
*
* The caller's Level 2 image may span non-contiguous physical blocks, so it
* cannot be used directly for a single Write Track DMA.  F$AllRAM #2 supplies
* two contiguous physical 8 KiB blocks.  F$MapBlk makes them temporarily
* visible in the FORMAT process, F$Move copies the track image, and F$ClrBlk
* removes that temporary mapping before DMA starts.  The DMA address is then
* generated directly from the F$AllRAM physical block number.
********************************************************************
ll_writetrack       lda       PD.DRV,y
                    cmpa      #2
                    lblo       LWTSize2D
                    cmpa      #4
                    lbhs      BadUnit
                    ldd       #WTrk2HDBytes
                    lbra       LWTSizeReady
LWTSize2D           ldd       #WTrk2DBytes
LWTSizeReady        std       V.WTrkLen,u

* Allocate exactly two consecutive Level 2 RAM blocks.  If physical memory is
* fragmented and F$AllRAM cannot find them, return E$NoRAM unchanged to FORMAT.
                    ldb       #WTrkBlocks
                    os9       F$AllRAM
                    lbcs      LWTAllocFail
                    std       V.WTrkBlk,u

* Temporarily map the two physical blocks into two adjacent logical blocks of
* the FORMAT process.  F$MapBlk returns the first logical address in U.
                    tfr       d,x
                    ldb       #WTrkBlocks
                    pshs      y,u
                    os9       F$MapBlk
                    lbcs      LWTMapFailStack
                    tfr       u,d
                    puls      y,u
                    std       V.WTrkMap,u

* Copy the caller's track image to the bounce mapping.  Source and destination
* are both in the current process task; F$Move handles arbitrary DAT layout.
                    pshs      y,u
                    ldx       PD.RGS,y
                    ldx       R$X,x
                    pshs      x
                    ldx       <D.Proc
                    lda       P$Task,x
                    tfr       a,b
                    puls      x
                    ldy       V.WTrkLen,u
                    ldu       V.WTrkMap,u
                    os9       F$Move
                    puls      y,u
                    lbcs      LWTMoveFail

* The copy is complete, so remove the temporary logical mapping.  Keep the
* physical blocks allocated until DMA has finished.
                    pshs      y,u
                    ldb       #WTrkBlocks
                    ldu       V.WTrkMap,u
                    os9       F$ClrBlk
                    puls      y,u
                    lbcs      LWTUnmapFail

                    lda       PD.DRV,y
                    cmpa      #2
                    lbhs       LWT2HD

* 2D MiniFDC / DMA0.
                    ldx       PD.RGS,y
                    lda       R$U+1,x
                    lbsr      SeekCylinder
                    lbcs      LWTIOError
                    lda       R$Y+1,x
                    anda      #$01
                    sta       >FM11_MFDC_SIDE
                    lda       PD.DRV,y
                    sta       >FM11_MFDC_DRIVE

                    ldd       V.WTrkBlk,u
                    lslb                ; first 4 KiB page = 2 * 8 KiB block
                    tfr       b,a
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
                    stb       >FM11_DMA0_ADDR_M
                    clr       >FM11_DMA0_ADDR_L
                    lda       #$19
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA0_MODE
                    lda       #FM11_MFDC_WRITETRK
                    sta       >FM11_MFDC_CMD
                    lbsr      DMA0Wait
                    lbcs       LWTIOError
                    lbsr      WaitMiniFDC
                    lbcs      LWTIOError
                    bita      #FM11_MFDC_ERRMASK
                    lbne      LWTIOError
                    lbra       LWTSuccess

* 2HD standard FDC / DMA1.
LWT2HD              cmpa      #4
                    lbhs      BadUnit
                    ldx       PD.RGS,y
                    lda       R$U+1,x
                    lbsr      SeekCylinder
                    lbcs      LWTIOError
                    lda       R$Y+1,x
                    anda      #$01
                    sta       >FM11_FDC_SIDE
                    lda       PD.DRV,y
                    suba      #2
                    sta       >FM11_FDC_DRIVE

                    ldd       V.WTrkBlk,u
                    lslb                ; first 4 KiB page = 2 * 8 KiB block
                    tfr       b,a
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
                    stb       >FM11_DMA1_ADDR_M
                    clr       >FM11_DMA1_ADDR_L
                    lda       #$2A
                    sta       >FM11_DMA1_COUNT_H
                    lda       #$94
                    sta       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA1_MODE
                    lda       #FM11_FDC_WRITETRK
                    sta       >FM11_FDC_CMD
                    lbsr      DMA1Wait
                    lbcs       LWTIOError
                    lbsr      WaitStdFDC
                    lbcs      LWTIOError
                    bita      #FM11_FDC_ERRMASK
                    lbne      LWTIOError

LWTSuccess          lbsr      LWTFreeRAM
                    lbra      StatOK

LWTIOError          lbsr      DiskIOFailed
                    ldb       #E$Write
                    pshs      b
                    lbsr      LWTFreeRAM
                    puls      b
                    orcc      #Carry
                    rts

* F$Move failed while the bounce blocks are still mapped.
LWTMoveFail         pshs      b
                    lbsr      LWTReleaseMapped
                    puls      b
                    orcc      #Carry
                    rts

* F$MapBlk failed.  Restore the driver's U/Y first, then release F$AllRAM.
LWTMapFailStack     puls      y,u
                    pshs      b
                    lbsr      LWTFreeRAM
                    puls      b
                    orcc      #Carry
                    rts

* F$ClrBlk unexpectedly failed.  Do not F$DelRAM a block that might still be
* present in the process DAT image.  Return the kernel error; the two blocks
* intentionally remain allocated rather than creating a dangling mapping.
LWTUnmapFail        orcc      #Carry
                    rts

LWTAllocFail        orcc      #Carry
                    rts

* Remove a successful temporary process mapping, then release the physical RAM.
* This is used only on a copy failure; normal flow has already called F$ClrBlk.
LWTReleaseMapped    pshs      y,u
                    ldb       #WTrkBlocks
                    ldu       V.WTrkMap,u
                    os9       F$ClrBlk
                    puls      y,u
                    lbcs       LWTReleaseDone
                    lbsr      LWTFreeRAM
LWTReleaseDone      rts

LWTFreeRAM          pshs      y,u
                    ldx       V.WTrkBlk,u
                    ldb       #WTrkBlocks
                    os9       F$DelRAM
                    puls      y,u
                    rts

UnknownSvc          orcc      #Carry
                    ldb       #E$UnkSvc
                    rts


********************************************************************
* SeekCylinder - A=target cylinder, U=private statics, Y=path.
* Preserve A/X/Y; B=OS-9 error on failure. Select drive before
* restoring its saved TRACK value. No verify on unformatted media.
********************************************************************
SeekCylinder        pshs      a,x,y
                    ldb       PD.DRV,y
                    cmpb      #4
                    bhs       SeekBadUnit
                    leax      V.CylPos,u
                    leax      b,x
                    cmpb      #2
                    bhs       SeekStd
                    ldy       #FM11_MFDC_CMD
                    clr       >FM11_DMA0_MODE
                    bra       SeekSelect
SeekStd             ldy       #FM11_FDC_CMD
                    clr       >FM11_DMA1_MODE
                    subb      #2
SeekSelect          stb       5,y
                    lbsr      WaitFDC
                    bcs       SeekFail
                    lda       ,x
                    bpl       SeekKnown
                    lda       #FM11_FDC_RESTORE_NOVERIFY
                    bsr       Type1Command
                    bcs       SeekFail
                    clra
                    sta       ,x
SeekKnown           sta       1,y
                    cmpa      ,s
                    beq       SeekDone
                    lda       ,s
                    sta       3,y
                    lda       #FM11_FDC_SEEK
                    bsr       Type1Command
                    bcs       SeekFail
                    lda       ,s
                    sta       ,x
SeekDone            clrb
                    andcc     #^Carry
                    puls      a,x,y,pc
SeekFail            lda       #$FF
                    sta       ,x
                    ldb       #E$Write
                    orcc      #Carry
                    puls      a,x,y
                    lbsr      DiskIOFailed
                    rts
SeekBadUnit         ldb       #E$Unit
                    orcc      #Carry
                    puls      a,x,y,pc

SeekReadError       ldb       #E$Read
                    orcc      #Carry
                    rts
SeekWriteError      orcc      #Carry
                    rts

* Wait for command completion with DMA disabled for Type I.
Type1Command        sta       ,y
                    ldb       #16
Type1Delay          decb
                    bne       Type1Delay
                    bsr       WaitFDC
                    bcs       Type1Done
                    bita      #FM11_FDC_TYPE1ERR
                    beq       Type1Done
                    orcc      #Carry
Type1Done           rts

WaitMiniFDC         pshs      y
                    ldy       #FM11_MFDC_CMD
                    bsr       WaitFDC
                    puls      y,pc
WaitStdFDC          pshs      y
                    ldy       #FM11_FDC_CMD
                    bsr       WaitFDC
                    puls      y,pc
WaitFDC             pshs      x,b
                    ldb       #64
WaitFDCOuter        ldx       #0
WaitFDCBusy         lda       ,y
                    bita      #FM11_FDC_BUSY
                    beq       WaitFDCDone
                    leax      -1,x
                    bne       WaitFDCBusy
                    decb
                    bne       WaitFDCOuter
                    orcc      #Carry
                    puls      x,b,pc
WaitFDCDone         andcc     #^Carry
                    puls      x,b,pc

InvalidateCylinder  pshs      d,x,cc
                    ldb       PD.DRV,y
                    cmpb      #4
                    bhs       InvDone
                    leax      V.CylPos,u
                    lda       #$FF
                    sta       b,x
InvDone             puls      d,x,cc,pc

* Stop the DMA channel before returning or freeing a bounce buffer.
* Force interrupt aborts a controller command that may still be BUSY.
* Preserve diagnostic status/error registers.
DiskIOFailed        pshs      d,cc
                    lbsr      InvalidateCylinder
                    lda       PD.DRV,y
                    cmpa      #2
                    bhs       DiskFailStd
                    clr       >FM11_DMA0_MODE
                    lda       #$D0
                    sta       >FM11_MFDC_CMD
                    lda       >FM11_MFDC_STATUS
                    bra       DiskFailDone
DiskFailStd         cmpa      #4
                    bhs       DiskFailDone
                    clr       >FM11_DMA1_MODE
                    lda       #$D0
                    sta       >FM11_FDC_CMD
                    lda       >FM11_FDC_STATUS
DiskFailDone        puls      d,cc,pc

                    emod
eom                 equ       *
                    end
