********************************************************************
* llfm11hd - FM-11 MDC hard-disk low-level driver for RBSuper
*
* FM-11 MDC hard-disk low-level driver shared by all supported HDD
* descriptors.  PD.DRV=4..7 map to MDC physical drives 0..3.
*
* The MDC is used in binary-address mode, so RBF physical LSNs map
* directly to MDC sector numbers.  Data transfers use DMA channel 2.
* Geometry is supplied by the active RBF device descriptor; the driver
* itself is not tied to a particular M223x/M224x model.
* This implementation is polling-only.  Private SetStat services install the HDD IPL and Bootp1 reserved area.
********************************************************************

                    nam       llfm11hd
                    ttl       FM-11 RBSuper MDC hard-disk driver

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

HDDBaseDrive        equ       4
MDCResultReady      equ       $40
MDCError            equ       $80
MDCBinaryMask       equ       $70
MDCDMA2Select       equ       $20

rev                 set       $00
edition             set       1
tylg                set       Sbrtn+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,start,0

                    org       V.LLMem
V.LocalSect         rmb       3
V.LocalCnt          rmb       1
V.LocalBuf          rmb       2

name                fcs       /llfm11hd/
                    fcb       edition

* RBSuper low-level jump table: init/read/write/getstat/setstat/term.
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
*   Select DMA channel 2 and the high drive-select bits in FDC2.
* Exit: A=physical MDC drive number, C clear; or E$Unit.
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

BadSector           orcc      #Carry
                    ldb       #E$Sect
                    rts

********************************************************************
* CheckSector
*
* RBSuper/RBF validates filesystem LSNs.  Do not impose a model-specific
* limit here: llfm11hd is shared by all supported M223x/M224x descriptors.
* The MDC reports an error if the selected physical unit rejects an address.
********************************************************************
CheckSector         clrb
                    andcc     #^Carry
                    rts

********************************************************************
* WaitResult - wait for MDC result phase, read and drain 10 result bytes.
* Result byte 0 bit 7 denotes error in the emulator's MDC implementation.
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
* SetupDMA2 - X=buffer, A=DMA direction bit (0 read, 1 write).
********************************************************************
SetupDMA2           pshs      a
                    clr       >FM11_DMA2_ADDR_H
                    stx       >FM11_DMA2_ADDR_M
                    lda       #1
                    sta       >FM11_DMA2_COUNT_H
                    clr       >FM11_DMA2_COUNT_L
                    puls      a
                    ora       #FM11_DMA_ENABLE
                    sta       >FM11_DMA2_MODE
                    rts

********************************************************************
* SendRWParams - send the 8-byte Read/Write parameter block.
* The current LSN is 24-bit, so the binary address high byte is zero.
********************************************************************
SendRWParams        lbsr      SelectDrive
                    bcs       SRP_Exit
                    anda      #1                  parameter 0: drive low bit
                    sta       >FM11_MDC_DATA
                    clr       >FM11_MDC_DATA       parameter 1
                    clr       >FM11_MDC_DATA       address bits 31..24
                    lda       V.LocalSect,u
                    sta       >FM11_MDC_DATA       address bits 23..16
                    lda       V.LocalSect+1,u
                    sta       >FM11_MDC_DATA       address bits 15..8
                    lda       V.LocalSect+2,u
                    sta       >FM11_MDC_DATA       address bits 7..0
                    lda       #1
                    sta       >FM11_MDC_DATA       byte count = $0100
                    clr       >FM11_MDC_DATA
                    clrb
                    andcc     #^Carry
SRP_Exit            rts

ReadSector          lbsr      CheckSector
                    bcs       RS_Exit
                    lbsr      SetBinary
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
RS_Exit             rts
RS_Error            orcc      #Carry
                    ldb       #E$Read
                    rts

WriteSector         lbsr      CheckSector
                    bcs       WS_Exit
                    lbsr      SetBinary
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
WS_Exit             rts
WS_Error            orcc      #Carry
                    ldb       #E$Write
                    rts

Advance             inc       V.LocalSect+2,u
                    bcc       ADV_Buf
                    inc       V.LocalSect+1,u
                    bcc       ADV_Buf
                    inc       V.LocalSect,u
ADV_Buf             inc       V.LocalBuf,u        +$0100 in 64K Level 1 space
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
* Return descriptor geometry in SS.DSize CHS mode.  This keeps one
* llfm11hd binary valid for every supported M223x/M224x descriptor and
* lets Format derive the exact capacity without a model-specific constant.
*   A = bytes/sector code (1 = 256 bytes)
*   B = sides/heads (non-zero selects CHS mode)
*   X = cylinders
*   Y = sectors/track
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
* Private HDD boot-area SetStat services.
*
* SS.FM11HDIPL  writes the 512-byte ROM IPL to physical sectors 0-1.
* SS.FM11HDBoot writes the 17-sector Bootp1 image to sectors 2-18.
* RBF descriptors use IT.SOFF=19, so normal filesystem LSN0 begins at
* physical sector 19 and these writes never overlap the filesystem.
********************************************************************
HDWriteAsset        stx       V.LocalBuf,u
                    sta       V.LocalSect+2,u
                    clr       V.LocalSect,u
                    clr       V.LocalSect+1,u
                    stb       V.LocalCnt,u
HDWA_Loop           lbsr      WriteSector
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
SS_HDIPL            ldx       R$X,x
                    clra                          physical sector 0
                    ldb       #2
                    bra       HDWriteAsset
SS_HDBoot           ldx       R$X,x
                    lda       #2                  physical sector 2
                    ldb       #17
                    bra       HDWriteAsset
SS_OK               clrb
                    andcc     #^Carry
                    rts

                    emod
eom                 equ       *
                    end
