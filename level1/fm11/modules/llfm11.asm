********************************************************************
* llfm11 - FM-11 low-level floppy driver for RBSuper
*
* PD.DRV mapping:
*   0 = /D0, /MD0 : built-in 5-inch 2D drive 0 (MiniFDC + DMA0)
*   1 = /D1, /MD1 : built-in 5-inch 2D drive 1 (MiniFDC + DMA0)
*   2 = /D2, /ND0 : built-in 5-inch 2HD drive 0 (standard FDC + DMA1)
*   3 = /D3, /ND1 : built-in 5-inch 2HD drive 1 (standard FDC + DMA1)
*
* 2D geometry:  40 cylinders x 2 sides x 16 x 256-byte sectors.
* 2HD geometry: 77 cylinders x 2 sides x 26 x 256-byte sectors for
*               RBF-visible tracks.  Track 0 is boot-only and hidden by
*               descriptor IT.SOFF=52; its side-0 128-byte special format
*               is therefore never accessed through RBSuper.
********************************************************************

                    nam       llfm11
                    ttl       FM-11 RBSuper low-level floppy driver

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

* FORMAT builds its Write Track image from LSN0 through u297E.
* The fixed buffer length is 10471 ($28E7) bytes.  The FM-11 emulator
* additionally caps the 2D controller at 6400 bytes per revolution.
FormatTrackBytes    equ       $28E7

rev                 set       $01
edition             set       4
tylg                set       Sbrtn+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,start,0

* Low-level private storage.  Keep all shared RBSuper variables intact.
                    org       V.LLMem
V.LocalSect         rmb       3
V.LocalCnt          rmb       1
V.LocalBuf          rmb       2

name                fcs       /llfm11/
                    fcb       edition

* RBSuper expects six entry points spaced exactly three bytes apart:
* init, read, write, getstat, setstat, term.
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
* SetupCHS
*
* Convert V.LocalSect to controller CHS according to PD.DRV.
* PD.DRV 0/1 use the 2D MiniFDC; 2/3 use the 2HD standard FDC.
********************************************************************
SetupCHS            lda       PD.DRV,y
                    cmpa      #2
                    blo       Setup2D
                    cmpa      #4
                    blo       Setup2HD
                    bra       BadUnit

Setup2D             tst       V.LocalSect,u
                    bne       BadSector
                    ldx       V.LocalSect+1,u
                    cmpx      #D2TotalSectors
                    bhs       BadSector

                    clra
S2_Cyl              cmpx      #D2SectorsPerCyl
                    blo       S2_GotCyl
                    leax      -D2SectorsPerCyl,x
                    inca
                    bra       S2_Cyl
S2_GotCyl           sta       >FM11_MFDC_TRACK
                    cmpx      #D2SectorsPerSide
                    blo       S2_Side0
                    leax      -D2SectorsPerSide,x
                    ldb       #1
                    bra       S2_GotSide
S2_Side0            clrb
S2_GotSide          stb       >FM11_MFDC_SIDE
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
SH_Cyl              cmpx      #HD2SectorsPerCyl
                    blo       SH_GotCyl
                    leax      -HD2SectorsPerCyl,x
                    inca
                    bra       SH_Cyl
SH_GotCyl           sta       >FM11_FDC_TRACK
                    cmpx      #HD2SectorsPerSide
                    blo       SH_Side0
                    leax      -HD2SectorsPerSide,x
                    ldb       #1
                    bra       SH_GotSide
SH_Side0            clrb
SH_GotSide          stb       >FM11_FDC_SIDE
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

* Advance local physical sector and buffer by one 256-byte sector.
Advance             inc       V.LocalSect+2,u
                    bcc       LL_ADVBUF
                    inc       V.LocalSect+1,u
                    bcc       LL_ADVBUF
                    inc       V.LocalSect,u
LL_ADVBUF           inc       V.LocalBuf,u        +$0100
                    rts

********************************************************************
* Read one physical 256-byte sector through the controller selected by
* PD.DRV.  SetupCHS must already have been called.
********************************************************************
ReadSector          lda       PD.DRV,y
                    cmpa      #2
                    bhs       Read2HD

Read2D              ldx       V.LocalBuf,u
                    clr       >FM11_DMA0_ADDR_H
                    stx       >FM11_DMA0_ADDR_M
                    lda       #1
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA0_MODE

                    lda       #FM11_MFDC_READSEC
                    sta       >FM11_MFDC_CMD

                    lda       >FM11_DMA0_MODE
                    bita      #FM11_DMA_ERROR
                    bne       ReadError
                    bita      #FM11_DMA_DONE
                    beq       ReadError
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       ReadError
                    clrb
                    andcc     #^Carry
                    rts

Read2HD             ldx       V.LocalBuf,u
                    clr       >FM11_DMA1_ADDR_H
                    stx       >FM11_DMA1_ADDR_M
                    lda       #1
                    sta       >FM11_DMA1_COUNT_H
                    clr       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE
                    sta       >FM11_DMA1_MODE

                    lda       #FM11_FDC_READSEC
                    sta       >FM11_FDC_CMD

                    lda       >FM11_DMA1_MODE
                    bita      #FM11_DMA_ERROR
                    bne       ReadError
                    bita      #FM11_DMA_DONE
                    beq       ReadError
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       ReadError
                    clrb
                    andcc     #^Carry
                    rts

ReadError           orcc      #Carry
                    ldb       #E$Read
                    rts

********************************************************************
* Write one physical 256-byte sector through the selected controller.
********************************************************************
WriteSector         lda       PD.DRV,y
                    cmpa      #2
                    bhs       Write2HD

Write2D             ldx       V.LocalBuf,u
                    clr       >FM11_DMA0_ADDR_H
                    stx       >FM11_DMA0_ADDR_M
                    lda       #1
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA0_MODE

                    lda       #FM11_MFDC_WRITESEC
                    sta       >FM11_MFDC_CMD

                    lda       >FM11_DMA0_MODE
                    bita      #FM11_DMA_ERROR
                    lbne      WriteError
                    bita      #FM11_DMA_DONE
                    lbeq      WriteError
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    lbne      WriteError
                    clrb
                    andcc     #^Carry
                    rts

Write2HD            ldx       V.LocalBuf,u
                    clr       >FM11_DMA1_ADDR_H
                    stx       >FM11_DMA1_ADDR_M
                    lda       #1
                    sta       >FM11_DMA1_COUNT_H
                    clr       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA1_MODE

                    lda       #FM11_FDC_WRITESEC
                    sta       >FM11_FDC_CMD

                    lda       >FM11_DMA1_MODE
                    bita      #FM11_DMA_ERROR
                    lbne      WriteError
                    bita      #FM11_DMA_DONE
                    lbeq      WriteError
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    lbne      WriteError
                    clrb
                    andcc     #^Carry
                    rts


********************************************************************
* Write2D256Diag - diagnostic 256-byte MiniFDC sector write for IPL.
* Returns B=$01 DMA error, $02 DMA incomplete, or raw MiniFDC status.
********************************************************************
Write2D256Diag      ldx       V.LocalBuf,u
                    clr       >FM11_DMA0_ADDR_H
                    stx       >FM11_DMA0_ADDR_M
                    lda       #1
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA0_MODE
                    lda       #FM11_MFDC_WRITESEC
                    sta       >FM11_MFDC_CMD
                    lda       >FM11_DMA0_MODE
                    bita      #FM11_DMA_ERROR
                    bne       W2D_DMAErr
                    bita      #FM11_DMA_DONE
                    beq       W2D_DMANotDone
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       W2D_FDCErr
                    clrb
                    andcc     #^Carry
                    rts
W2D_DMAErr          ldb       #$01
                    orcc      #Carry
                    rts
W2D_DMANotDone      ldb       #$02
                    orcc      #Carry
                    rts
W2D_FDCErr          tfr       a,b
                    orcc      #Carry
                    rts
Write2HD128         ldx       V.LocalBuf,u
                    clr       >FM11_DMA1_ADDR_H
                    stx       >FM11_DMA1_ADDR_M
                    clr       >FM11_DMA1_COUNT_H
                    lda       #$80
                    sta       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA1_MODE
                    lda       #FM11_FDC_WRITESEC
                    sta       >FM11_FDC_CMD
                    lda       >FM11_DMA1_MODE
                    bita      #FM11_DMA_ERROR
                    bne       W128_DMAErr
                    bita      #FM11_DMA_DONE
                    beq       W128_DMANotDone
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       W128_FDCErr
                    clrb
                    andcc     #^Carry
                    rts
W128_DMAErr         ldb       #$01                diagnostic: DMA error
                    orcc      #Carry
                    rts
W128_DMANotDone     ldb       #$02                diagnostic: DMA did not complete
                    orcc      #Carry
                    rts
W128_FDCErr         tfr       a,b                 return raw FDC status to Cobbler
                    orcc      #Carry
                    rts

WriteError          orcc      #Carry
                    ldb       #E$Write
                    rts

********************************************************************
* ll_read / ll_write
********************************************************************
ll_read             lda       V.PhysSect,u
                    ldx       V.PhysSect+1,u
                    sta       V.LocalSect,u
                    stx       V.LocalSect+1,u
                    lda       V.SectCnt,u
                    sta       V.LocalCnt,u
                    ldx       V.CchPSpot,u
                    stx       V.LocalBuf,u

LL_RDLOOP           lbsr      SetupCHS
                    bcs       LL_RDEXIT
                    lbsr      ReadSector
                    bcs       LL_RDEXIT
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    bne       LL_RDLOOP
                    clrb
                    andcc     #^Carry
LL_RDEXIT           rts

ll_write            lda       V.PhysSect,u
                    ldx       V.PhysSect+1,u
                    sta       V.LocalSect,u
                    stx       V.LocalSect+1,u
                    lda       V.SectCnt,u
                    sta       V.LocalCnt,u
                    ldx       V.CchPSpot,u
                    stx       V.LocalBuf,u

LL_WRLOOP           lbsr      SetupCHS
                    bcs       LL_WREXIT
                    lbsr      WriteSector
                    bcs       LL_WREXIT
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    bne       LL_WRLOOP
                    clrb
                    andcc     #^Carry
LL_WREXIT           rts

********************************************************************
* GetStat / SetStat
********************************************************************
ll_getstat          ldx       PD.RGS,y
                    lda       R$B,x
                    cmpa      #SS.DSize
                    bne       gs_unknown
* B=0 selects LBA-style return: A=sector size in 256-byte units,
* X:Y=32-bit physical-sector count.
                    lda       #1
                    sta       R$A,x
                    clr       R$B,x
                    clra
                    clrb
                    std       R$X,x
                    lda       PD.DRV,y
                    cmpa      #2
                    bhs       gs_2hd
                    ldd       #D2TotalSectors
                    bra       gs_size

gs_2hd              cmpa      #4
                    lbhs      BadUnit
                    ldd       #HD2TotalSectors
gs_size             std       R$Y,x
                    clrb
                    andcc     #^Carry
                    rts

gs_unknown          orcc      #Carry
                    ldb       #E$UnkSvc
                    rts

ll_setstat          ldx       PD.RGS,y
                    lda       R$B,x
                    cmpa      #SS.SQD
                    lbeq      ss_ok
                    cmpa      #SS.Reset
                    lbeq      ll_reset
                    cmpa      #SS.WTrk
                    lbeq      ll_writetrack
                    cmpa      #SS.FM11Boot
                    lbeq      ll_boottrack
                    cmpa      #SS.FM11IPL
                    lbeq      ll_ipl
                    orcc      #Carry
                    ldb       #E$UnkSvc
                    rts

********************************************************************
* SS.Reset - restore the selected floppy controller to track zero.
********************************************************************
ll_reset            lda       PD.DRV,y
                    cmpa      #2
                    bhs       LR_2HD
                    sta       >FM11_MFDC_DRIVE
                    clr       >FM11_MFDC_SIDE
                    lda       #FM11_MFDC_RESTORE
                    sta       >FM11_MFDC_CMD
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       LR_Error
                    lbra      ss_ok

LR_2HD              cmpa      #4
                    lbhs      BadUnit
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    clr       >FM11_FDC_SIDE
                    lda       #FM11_FDC_RESTORE
                    sta       >FM11_FDC_CMD
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       LR_Error
                    lbra      ss_ok

LR_Error            orcc      #Carry
                    ldb       #E$Write
                    rts


********************************************************************
* SS.FM11IPL - write the reserved ROM IPL slots at physical T0/H0.
*
* Boot-ROM analysis shows different native layouts:
*   2D:  ROM reads S1-S2 as 2 x 256 bytes.  The established NitrOS-9 layout
*        also reserves S3-S4, so this routine intentionally writes four
*        256-byte slots and keeps the boottrack start at S5.
*   2HD: ROM reads S1-S4 as 4 x 128 bytes.
* FORMAT first creates the sector IDs with SS.WTrk; this routine then writes
* the corresponding reserved slots without changing the existing layout.
********************************************************************
ll_ipl              ldx       PD.RGS,y
                    ldx       R$X,x
                    stx       V.LocalBuf,u
                    lda       #4
                    sta       V.LocalCnt,u
                    lda       PD.DRV,y
                    cmpa      #2
                    bhs       LIPL_2HD

LIPL_2D             sta       >FM11_MFDC_DRIVE
                    clr       >FM11_MFDC_TRACK
                    clr       >FM11_MFDC_SIDE
                    lda       #1
                    sta       >FM11_MFDC_SECTOR
LIPL_2DLoop         lbsr      Write2D256Diag
                    bcs       LIPL_Exit
                    inc       V.LocalBuf,u
                    inc       >FM11_MFDC_SECTOR
                    dec       V.LocalCnt,u
                    bne       LIPL_2DLoop
                    lbra      ss_ok

LIPL_2HD            cmpa      #4
                    lbhs      BadUnit
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    clr       >FM11_FDC_TRACK
                    clr       >FM11_FDC_SIDE
                    lda       #1
                    sta       >FM11_FDC_SECTOR
LIPL_2HDLoop        lbsr      Write2HD128
                    bcs       LIPL_Exit
                    ldd       V.LocalBuf,u
                    addd      #$0080
                    std       V.LocalBuf,u
                    inc       >FM11_FDC_SECTOR
                    dec       V.LocalCnt,u
                    bne       LIPL_2HDLoop
                    lbra      ss_ok
LIPL_Exit           rts

********************************************************************
* SS.FM11Boot - rewrite only the reserved NitrOS-9 boottrack sectors.
*
* The reserved IPL area is deliberately left untouched.  On 2D the ROM
* itself reads S1-S2 but S1-S4 remain reserved by the current layout; on
* 2HD the ROM reads S1-S4 as 128-byte sectors.  Cobbler passes the
* target-specific 17-sector boottrack image
* in R$X, so the target media profile is independent of the booted system.
* For 2D this crosses from H0/S16 to H1/S1; native 2HD uses H1/S1-S17.
********************************************************************
ll_boottrack        ldx       PD.RGS,y
                    ldx       R$X,x              target-specific boottrack buffer
                    stx       V.LocalBuf,u
                    lda       #17
                    sta       V.LocalCnt,u
                    lda       PD.DRV,y
                    cmpa      #2
                    bhs       LBT_2HD

LBT_2D              sta       >FM11_MFDC_DRIVE
                    clr       >FM11_MFDC_TRACK
                    clr       >FM11_MFDC_SIDE
                    lda       #5
                    sta       >FM11_MFDC_SECTOR
LBT_2DLoop           lbsr      WriteSector
                    bcs       LBT_Exit
                    inc       V.LocalBuf,u
                    inc       >FM11_MFDC_SECTOR
                    lda       >FM11_MFDC_SECTOR
                    cmpa      #17
                    blo       LBT_2DNext
                    lda       #1
                    sta       >FM11_MFDC_SECTOR
                    lda       >FM11_MFDC_SIDE
                    eora      #1
                    sta       >FM11_MFDC_SIDE
LBT_2DNext           dec       V.LocalCnt,u
                    bne       LBT_2DLoop
                    lbra      ss_ok

LBT_2HD             cmpa      #4
                    lbhs      BadUnit
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    clr       >FM11_FDC_TRACK
                    lda       #1
                    sta       >FM11_FDC_SIDE
                    lda       #1
                    sta       >FM11_FDC_SECTOR
LBT_2HDLoop          lbsr      WriteSector
                    bcs       LBT_Exit
                    inc       V.LocalBuf,u
                    inc       >FM11_FDC_SECTOR
                    dec       V.LocalCnt,u
                    bne       LBT_2HDLoop
                    lbra      ss_ok

LBT_Exit             rts

********************************************************************
* SS.WTrk - write one complete format track image.
*
* FORMAT register convention:
*   R$X = address of Write Track image
*   R$U = physical track number
*   R$Y low byte bit 0 = side (other bits are density/TPI hints)
*
* FM-11 Format reserves physical cylinder 0 and passes cylinder 1 onward.
********************************************************************
ll_writetrack       lda       PD.DRV,y
                    cmpa      #2
                    bhs       LWT_2HD

LWT_2D              ldx       PD.RGS,y
                    ldb       R$U+1,x
                    stb       >FM11_MFDC_TRACK
                    lda       R$Y+1,x
                    anda      #$01
                    sta       >FM11_MFDC_SIDE
                    lda       PD.DRV,y
                    sta       >FM11_MFDC_DRIVE
                    ldx       R$X,x
                    clr       >FM11_DMA0_ADDR_H
                    stx       >FM11_DMA0_ADDR_M
                    lda       #$19                6400 bytes = $1900
                    sta       >FM11_DMA0_COUNT_H
                    clr       >FM11_DMA0_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA0_MODE
                    lda       #FM11_MFDC_WRITETRK
                    sta       >FM11_MFDC_CMD
                    lda       >FM11_DMA0_MODE
                    bita      #FM11_DMA_ERROR
                    bne       LWT_Error
                    lda       >FM11_MFDC_STATUS
                    bita      #FM11_MFDC_ERRMASK
                    bne       LWT_Error
                    lbra      ss_ok

LWT_2HD             cmpa      #4
                    lbhs      BadUnit
                    ldx       PD.RGS,y
                    ldb       R$U+1,x
                    stb       >FM11_FDC_TRACK
                    lda       R$Y+1,x
                    anda      #$01
                    sta       >FM11_FDC_SIDE
                    lda       PD.DRV,y
                    suba      #2
                    sta       >FM11_FDC_DRIVE
                    ldx       R$X,x
                    clr       >FM11_DMA1_ADDR_H
                    stx       >FM11_DMA1_ADDR_M
                    lda       #$2A                10900 bytes = $2A94
                    sta       >FM11_DMA1_COUNT_H
                    lda       #$94
                    sta       >FM11_DMA1_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA1_MODE
                    lda       #FM11_FDC_WRITETRK
                    sta       >FM11_FDC_CMD
                    lda       >FM11_DMA1_MODE
                    bita      #FM11_DMA_ERROR
                    bne       LWT_Error
                    lda       >FM11_FDC_STATUS
                    bita      #FM11_FDC_ERRMASK
                    bne       LWT_Error
                    lbra      ss_ok

LWT_Error           orcc      #Carry
                    ldb       #E$Write
                    rts

ss_ok               clrb
                    andcc     #^Carry
                    rts

                    emod
eom                 equ       *
                    end
