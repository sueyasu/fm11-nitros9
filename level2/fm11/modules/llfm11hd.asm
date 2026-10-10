********************************************************************
* llfm11hd - FM-11 Level 2 MDC hard-disk low-level driver for RBSuper
*
* PD.DRV=4 maps /H0 to MDC physical drive 0.  The driver keeps the
* Level 1 binary-sector-address protocol, but DMA channel 2 addresses
* are translated through the active Level 2 4 KiB MMR mapping.
*
* Private SetStat services write the ROM IPL and the 21-sector Level 2
* kernel track into the reserved physical boot area.
********************************************************************

                    nam       llfm11hd
                    ttl       FM-11 Level 2 RBSuper MDC hard-disk driver

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

HDDBaseDrive        equ       4
MDCResultReady      equ       $40
MDCError            equ       $80
MDCBinaryMask       equ       $70
MDCDMA2Select       equ       $20

AssetBlocks         equ       1
HDIPLAssetBytes     equ       512
HDBootAssetBytes    equ       21*256

rev                 set       $00
edition             set       1
tylg                set       Sbrtn+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,start,0

                    org       V.LLMem
V.LocalSect         rmb       3
V.LocalCnt          rmb       1
V.LocalBuf          rmb       2
V.AssetBlk          rmb       2
V.AssetMap          rmb       2
V.AssetLen          rmb       2

name                fcs       /llfm11hd/
                    fcb       edition

* RBSuper low-level ABI: init/read/write/getstat/setstat/term.
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
* SelectDrive
*   PD.DRV 4..7 map to MDC drives 0..3.
********************************************************************
SelectDrive         lda       PD.DRV,y
                    suba      #HDDBaseDrive
                    cmpa      #4
                    bhs       BadUnit
                    pshs      a
                    lsra
                    anda      #$03
                    ora       #MDCDMA2Select
                    sta       >FM11_MDC_SELECT
                    puls      a
                    andcc     #^Carry
                    rts

BadUnit             orcc      #Carry
                    ldb       #E$Unit
                    rts

********************************************************************
* WaitResult - wait for MDC result phase and drain 10 result bytes.
********************************************************************
WaitResult          ldx       #$FFFF
WR_Wait             lda       >FM11_MDC_STATUS
                    bita      #MDCResultReady
                    bne       WR_Ready
                    leax      -1,x
                    bne       WR_Wait
                    orcc      #Carry
                    ldb       #E$NotRdy
                    rts
WR_Ready            lda       >FM11_MDC_DATA
                    pshs      a
                    ldb       #9
WR_Drain            lda       >FM11_MDC_DATA
                    decb
                    bne       WR_Drain
                    puls      a
                    bita      #MDCError
                    bne       WR_Error
                    clrb
                    andcc     #^Carry
                    rts
WR_Error            orcc      #Carry
                    ldb       #E$NotRdy
                    rts

********************************************************************
* SetBinary - put selected MDC drive into binary sector-address mode.
********************************************************************
SetBinary           lbsr      SelectDrive
                    bcs       SB_Exit
                    pshs      a
                    lda       #FM11_MDC_SETCMASK
                    sta       >FM11_MDC_CMD
                    puls      a
                    anda      #1
                    ora       #MDCBinaryMask
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    lbsr      WaitResult
SB_Exit             rts

********************************************************************
* SetupDMA2
*
* Entry:
*   X = Level 2 logical buffer address
*   A = DMA direction bit (0 read, FM11_DMA_DIR_WRITE for write)
*
* DMA sees physical memory.  Translate the logical address through the
* currently active 4 KiB MMR exactly as the floppy DMA paths do.
********************************************************************
SetupDMA2           pshs      a
                    pshs      d,x,y
                    tfr       x,d
                    stb       >FM11_DMA2_ADDR_L
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
                    sta       >FM11_DMA2_ADDR_H
                    andb      #$0F
                    lslb
                    lslb
                    lslb
                    lslb
                    puls      a
                    anda      #$0F
                    pshs      b
                    ora       ,s+
                    sta       >FM11_DMA2_ADDR_M

                    lda       #1
                    sta       >FM11_DMA2_COUNT_H
                    clr       >FM11_DMA2_COUNT_L
                    puls      d,x,y
                    puls      a
                    ora       #FM11_DMA_ENABLE
                    sta       >FM11_DMA2_MODE
                    rts

********************************************************************
* SendRWParams - send one-sector Read/Write parameter block.
********************************************************************
SendRWParams        lbsr      SelectDrive
                    bcs       SRP_Exit
                    anda      #1
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    lda       V.LocalSect,u
                    sta       >FM11_MDC_DATA
                    lda       V.LocalSect+1,u
                    sta       >FM11_MDC_DATA
                    lda       V.LocalSect+2,u
                    sta       >FM11_MDC_DATA
                    lda       #1
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA
                    clrb
                    andcc     #^Carry
SRP_Exit            rts

ReadSector          lbsr      SetBinary
                    bcs       RS_Error
                    ldx       V.LocalBuf,u
                    clra
                    lbsr      SetupDMA2
                    lda       #FM11_MDC_READ
                    sta       >FM11_MDC_CMD
                    lbsr      SendRWParams
                    bcs       RS_Error
                    lbsr      WaitResult
                    bcs       RS_Error
                    lda       >FM11_DMA2_MODE
                    bita      #FM11_DMA_ERROR
                    bne       RS_Error
                    bita      #FM11_DMA_DONE
                    beq       RS_Error
                    clrb
                    andcc     #^Carry
                    rts
RS_Error            orcc      #Carry
                    ldb       #E$Read
                    rts

WriteSector         lbsr      SetBinary
                    bcs       WS_Error
                    ldx       V.LocalBuf,u
                    lda       #FM11_DMA_DIR_WRITE
                    lbsr      SetupDMA2
                    lda       #FM11_MDC_WRITE
                    sta       >FM11_MDC_CMD
                    lbsr      SendRWParams
                    bcs       WS_Error
                    lbsr      WaitResult
                    bcs       WS_Error
                    lda       >FM11_DMA2_MODE
                    bita      #FM11_DMA_ERROR
                    bne       WS_Error
                    bita      #FM11_DMA_DONE
                    beq       WS_Error
                    clrb
                    andcc     #^Carry
                    rts
WS_Error            orcc      #Carry
                    ldb       #E$Write
                    rts

Advance             inc       V.LocalSect+2,u
                    bcc       ADV_Buf
                    inc       V.LocalSect+1,u
                    bcc       ADV_Buf
                    inc       V.LocalSect,u
ADV_Buf             inc       V.LocalBuf,u
                    rts

ll_read             lda       V.PhysSect,u
                    ldx       V.PhysSect+1,u
                    sta       V.LocalSect,u
                    stx       V.LocalSect+1,u
                    lda       V.SectCnt,u
                    sta       V.LocalCnt,u
                    ldx       V.CchPSpot,u
                    stx       V.LocalBuf,u
RD_Loop             lbsr      ReadSector
                    bcs       RD_Exit
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    bne       RD_Loop
                    clrb
                    andcc     #^Carry
RD_Exit             rts

ll_write            lda       V.PhysSect,u
                    ldx       V.PhysSect+1,u
                    sta       V.LocalSect,u
                    stx       V.LocalSect+1,u
                    lda       V.SectCnt,u
                    sta       V.LocalCnt,u
                    ldx       V.CchPSpot,u
                    stx       V.LocalBuf,u
WR_Loop             lbsr      WriteSector
                    bcs       WR_Exit
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    bne       WR_Loop
                    clrb
                    andcc     #^Carry
WR_Exit             rts

ll_getstat          ldx       PD.RGS,y
                    lda       R$B,x
                    cmpa      #SS.DSize
                    bne       GS_Unknown
* Return descriptor geometry in CHS form.
                    lda       #1
                    sta       R$A,x
                    lda       PD.SID,y
                    sta       R$B,x
                    ldd       PD.CYL,y
                    std       R$X,x
                    ldd       PD.SCT,y
                    std       R$Y,x
                    clrb
                    andcc     #^Carry
                    rts
GS_Unknown          orcc      #Carry
                    ldb       #E$UnkSvc
                    rts

********************************************************************
* HDD Cobbler asset bounce buffer.
********************************************************************
HDAssetPrepare      std       V.AssetLen,u
                    ldb       #AssetBlocks
                    os9       F$AllRAM
                    bcs       HDAssetAllocFail
                    std       V.AssetBlk,u

                    tfr       d,x
                    ldb       #AssetBlocks
                    pshs      y,u
                    os9       F$MapBlk
                    bcs       HDAssetMapFailStack
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
                    bcs       HDAssetMoveFail

                    pshs      y,u
                    ldb       #AssetBlocks
                    ldu       V.AssetMap,u
                    os9       F$ClrBlk
                    puls      y,u
                    bcs       HDAssetUnmapFail

                    clra
                    clrb
                    std       V.LocalBuf,u
                    andcc     #^Carry
                    rts

HDAssetMapFailStack puls      y,u
                    pshs      b
                    lbsr      HDAssetFreeRAM
                    puls      b
                    orcc      #Carry
                    rts

HDAssetMoveFail     pshs      b
                    lbsr      HDAssetReleaseMapped
                    puls      b
                    orcc      #Carry
                    rts

HDAssetUnmapFail    orcc      #Carry
                    rts
HDAssetAllocFail    orcc      #Carry
                    rts

HDAssetReleaseMapped
                    pshs      y,u
                    ldb       #AssetBlocks
                    ldu       V.AssetMap,u
                    os9       F$ClrBlk
                    puls      y,u
                    bcs       HDAssetReleaseDone
                    lbsr      HDAssetFreeRAM
HDAssetReleaseDone  rts

HDAssetFreeRAM      pshs      y,u
                    ldx       V.AssetBlk,u
                    ldb       #AssetBlocks
                    os9       F$DelRAM
                    puls      y,u
                    rts

SetupHDAssetDMA2    lda       V.AssetBlk+1,u
                    pshs      a
                    lsra
                    lsra
                    lsra
                    sta       >FM11_DMA2_ADDR_H
                    puls      a
                    anda      #$07
                    lsla
                    lsla
                    lsla
                    lsla
                    lsla
                    adda      V.LocalBuf,u
                    sta       >FM11_DMA2_ADDR_M
                    lda       V.LocalBuf+1,u
                    sta       >FM11_DMA2_ADDR_L
                    rts

WriteHDAssetSector  lbsr      SetBinary
                    bcs       WHDASError
                    lbsr      SetupHDAssetDMA2
                    lda       #1
                    sta       >FM11_DMA2_COUNT_H
                    clr       >FM11_DMA2_COUNT_L
                    lda       #FM11_DMA_ENABLE+FM11_DMA_DIR_WRITE
                    sta       >FM11_DMA2_MODE
                    lda       #FM11_MDC_WRITE
                    sta       >FM11_MDC_CMD
                    lbsr      SendRWParams
                    bcs       WHDASError
                    lbsr      WaitResult
                    bcs       WHDASError
                    lda       >FM11_DMA2_MODE
                    bita      #FM11_DMA_ERROR
                    bne       WHDASError
                    bita      #FM11_DMA_DONE
                    beq       WHDASError
                    clrb
                    andcc     #^Carry
                    rts
WHDASError          orcc      #Carry
                    ldb       #E$Write
                    rts

HDWriteAsset
                    sta       V.LocalSect+2,u
                    clr       V.LocalSect,u
                    clr       V.LocalSect+1,u
                    stb       V.LocalCnt,u
HDWA_Loop           lbsr      WriteHDAssetSector
                    bcs       HDWA_Exit
                    lbsr      Advance
                    dec       V.LocalCnt,u
                    bne       HDWA_Loop
                    clrb
                    andcc     #^Carry
HDWA_Exit           rts

ll_setstat          ldx       PD.RGS,y
                    lda       R$B,x
                    cmpa      #SS.FM11HDIPL
                    beq       SS_HDIPL
                    cmpa      #SS.FM11HDBoot
                    beq       SS_HDBoot
                    cmpa      #SS.SQD
                    beq       SS_OK
                    cmpa      #SS.Reset
                    beq       SS_OK
                    orcc      #Carry
                    ldb       #E$UnkSvc
                    rts

SS_HDIPL            ldd       #HDIPLAssetBytes
                    lbsr      HDAssetPrepare
                    bcs       SS_HDExit
                    clra
                    ldb       #2
                    lbsr      HDWriteAsset
                    bcs       SS_HDIOExit
                    lbsr      HDAssetFreeRAM
                    bra       SS_OK

SS_HDBoot           ldd       #HDBootAssetBytes
                    lbsr      HDAssetPrepare
                    bcs       SS_HDExit
                    lda       #2
                    ldb       #21
                    lbsr      HDWriteAsset
                    bcs       SS_HDIOExit
                    lbsr      HDAssetFreeRAM
                    bra       SS_OK

SS_HDIOExit         pshs      b
                    lbsr      HDAssetFreeRAM
                    puls      b
                    orcc      #Carry
SS_HDExit           rts

SS_OK               clrb
                    andcc     #^Carry
                    rts

                    emod
eom                 equ       *
                    end
