********************************************************************
* llfm11 - FM-11 Level 2 low-level 2D floppy driver for RBSuper
*
* Initial Level 2 implementation deliberately uses MiniFDC PIO rather
* than DMA.  DMA sees physical memory while RBSuper buffers are Level 2
* logical addresses, so passing V.CchPSpot directly to DMA is unsafe.
*
* Geometry:
*   40 cylinders x 2 sides x 16 x 256-byte sectors
* RBF descriptors reserve physical sectors 0..31 for IPL/kernel track.
********************************************************************

                    nam       llfm11
                    ttl       FM-11 Level 2 2D PIO floppy driver

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

D2SectorsPerSide    equ       16
D2SectorsPerCyl     equ       32
D2TotalSectors      equ       40*D2SectorsPerCyl
PIOTimeout          equ       0

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
* SetupCHS - convert V.LocalSect to MiniFDC cylinder/side/sector.
********************************************************************
SetupCHS            lda       PD.DRV,y
                    cmpa      #2
                    bhs       BadUnit

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
                    bne       PIOReadError
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
* ReadSector / WriteSector - 256-byte PIO transfers.
********************************************************************
ReadSector          lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD
                    ldx       V.LocalBuf,u
                    ldy       #256
ReadByte            bsr       WaitDRQ
                    bcs       ReadDone
                    lda       >FM11_MFDC_DATA
                    sta       ,x+
                    leay      -1,y
                    bne       ReadByte
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       PIOReadError
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

WriteSector         lda       #FM11_MFDC_WRITESEC
                    sta       >FM11_MFDC_CMD
                    ldx       V.LocalBuf,u
                    ldy       #256
WriteByte           bsr       WaitWriteDRQ
                    bcs       WriteDone
                    lda       ,x+
                    sta       >FM11_MFDC_DATA
                    leay      -1,y
                    bne       WriteByte
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       PIOWriteError
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
                    bsr       WriteSector
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
                    ldd       #D2TotalSectors
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
                    lbhs      BadUnit
                    sta       >FM11_MFDC_DRIVE
                    clr       >FM11_MFDC_SIDE
                    lda       #FM11_MFDC_RESTORE
                    sta       >FM11_MFDC_CMD
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
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
