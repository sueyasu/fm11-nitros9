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

rev                 set       $00
edition             set       1
tylg                set       Sbrtn+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,start,0

                    org       V.LLMem
V.LocalSect         rmb       3
V.LocalCnt          rmb       1
V.LocalBuf          rmb       2

name                fcs       /llfm11/
                    fcb       edition

* RBSuper low-level ABI: six LBRA entry points, exactly three bytes apart.
start               lbra      ll_init
                    lbra      ll_read
                    lbra      ll_write
                    lbra      ll_getstat
                    lbra      ll_setstat
                    lbra      ll_term

ll_init             clrb
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
                    blo       Setup2D
                    cmpa      #4
                    blo       Setup2HD
                    bra       BadUnit

Setup2D
                    tst       V.LocalSect,u
                    bne       BadSector
                    ldx       V.LocalSect+1,u
                    cmpx      #D2TotalSectors
                    bhs       BadSector

                    clra
S2Cyl               cmpx      #D2SectorsPerCyl
                    blo       S2GotCyl
                    leax      -D2SectorsPerCyl,x
                    inca
                    bra       S2Cyl
S2GotCyl            sta       >FM11_MFDC_TRACK

                    cmpx      #D2SectorsPerSide
                    blo       S2Side0
                    leax      -D2SectorsPerSide,x
                    ldb       #1
                    bra       S2GotSide
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
                    bne       BadSector
                    ldx       V.LocalSect+1,u
                    cmpx      #HD2TotalSectors
                    bhs       BadSector

                    clra
SHCyl               cmpx      #HD2SectorsPerCyl
                    blo       SHGotCyl
                    leax      -HD2SectorsPerCyl,x
                    inca
                    bra       SHCyl
SHGotCyl            sta       >FM11_FDC_TRACK

                    cmpx      #HD2SectorsPerSide
                    blo       SHSide0
                    leax      -HD2SectorsPerSide,x
                    ldb       #1
                    bra       SHGotSide
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
                    bcc       AdvBuf
                    inc       V.LocalSect+1,u
                    bcc       AdvBuf
                    inc       V.LocalSect,u
AdvBuf              inc       V.LocalBuf,u
                    rts

********************************************************************
* WaitDRQ
*
* Exit: carry clear when DRQ is asserted.
*       carry set/B=E$Read when controller error or timeout occurs.
********************************************************************
WaitDRQ             pshs      x
                    ldx       #PIOTimeout
WaitDRQLoop         lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    lbne      PIOReadError
                    bita      #FM11_MFDC_DRQ
                    bne       WaitDRQDone
                    leax      -1,x
                    cmpx      #0
                    bne       WaitDRQLoop
PIOReadError        puls      x
                    orcc      #Carry
                    ldb       #E$Read
                    rts
WaitDRQDone         puls      x
                    clrb
                    andcc     #^Carry
                    rts

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
                    bne       DMA0WaitError
                    bita      #FM11_DMA_DONE
                    bne       DMA0WaitDone
                    leax      -1,x
                    cmpx      #0
                    bne       DMA0WaitLoop
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
                    bne       DMA1WaitError
                    bita      #FM11_DMA_DONE
                    bne       DMA1WaitDone
                    leax      -1,x
                    cmpx      #0
                    bne       DMA1WaitLoop
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
                    bcs       DMAReadError
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       DMAReadError
                    clrb
                    andcc     #^Carry
                    rts
DMAReadError        orcc      #Carry
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
                    bcs       DMAReadError
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       DMAReadError
                    clrb
                    andcc     #^Carry
                    rts

ReadSectorPIO       lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD
                    ldx       V.LocalBuf,u
                    ldy       #256
ReadByte            lbsr      WaitDRQ
                    bcs       ReadDone
                    lda       >FM11_MFDC_DATA
                    sta       ,x+
                    leay      -1,y
                    bne       ReadByte
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    lbne      PIOReadError
                    clrb
                    andcc     #^Carry
ReadDone            rts

WaitWriteDRQ        pshs      x
                    ldx       #PIOTimeout
WaitWriteLoop       lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       PIOWriteError
                    bita      #FM11_MFDC_DRQ
                    bne       WaitWriteDone
                    leax      -1,x
                    cmpx      #0
                    bne       WaitWriteLoop
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
                    bcs       DMAWriteError
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       DMAWriteError
                    clrb
                    andcc     #^Carry
                    rts
DMAWriteError       orcc      #Carry
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
                    bcs       DMAWriteError
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       DMAWriteError
                    clrb
                    andcc     #^Carry
                    rts

WriteSectorPIO      lda       #FM11_MFDC_WRITESEC
                    sta       >FM11_MFDC_CMD
                    ldx       V.LocalBuf,u
                    ldy       #256
WriteByte           lbsr      WaitWriteDRQ
                    bcs       WriteDone
                    lda       ,x+
                    sta       >FM11_MFDC_DATA
                    leay      -1,y
                    bne       WriteByte
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    lbne      PIOWriteError
                    clrb
                    andcc     #^Carry
WriteDone           rts

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
                    bcs       ReadExit
                    lbsr      ReadSector
                    bcs       ReadExit
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    bne       ReadLoop
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
                    bcs       WriteExit
                    lbsr      WriteSector
                    bcs       WriteExit
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    bne       WriteLoop
                    clrb
                    andcc     #^Carry
WriteExit           rts

********************************************************************
* Minimal GetStat/SetStat needed for normal RBF operation.
********************************************************************
ll_getstat          ldx       PD.RGS,y
                    lda       R$B,x
                    cmpa      #SS.DSize
                    bne       UnknownSvc
                    lda       #1
                    sta       R$A,x
                    clr       R$B,x
                    clra
                    clrb
                    std       R$X,x
                    lda       PD.DRV,y
                    cmpa      #2
                    bhs       GetSize2HD
                    ldd       #D2TotalSectors
                    bra       GetSizeDone
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
                    beq       StatOK
                    cmpa      #SS.Reset
                    bne       UnknownSvc

                    lda       PD.DRV,y
                    cmpa      #2
                    bhs       Reset2HD
                    sta       >FM11_MFDC_DRIVE
                    clr       >FM11_MFDC_SIDE
                    lda       #FM11_MFDC_RESTORE
                    sta       >FM11_MFDC_CMD
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       ResetError
                    bra       StatOK

Reset2HD            cmpa      #4
                    lbhs      BadUnit
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    clr       >FM11_FDC_SIDE
                    lda       #FM11_FDC_RESTORE
                    sta       >FM11_FDC_CMD
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       ResetError
StatOK              clrb
                    andcc     #^Carry
                    rts

ResetError          orcc      #Carry
                    ldb       #E$Write
                    rts

UnknownSvc          orcc      #Carry
                    ldb       #E$UnkSvc
                    rts

                    emod
eom                 equ       *
                    end
