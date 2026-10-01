                    IFNE      FM11.D-1
FM11.D              SET       1
Color               SET       1
CPUType             SET       Color
TkPerSec            SET       50
PwrLnFrq            SET       50
SHIFTBIT            EQU       %00000001
Bt.Start            EQU       $EB00
Bt.Size             EQU       $1080
* FM-11 interrupt controller / PTM (MC6840-compatible timer)
FM11_IRQEN          EQU       $FD02
FM11_IRQSTAT        EQU       $FD03
FM11_IRQ_PTM        EQU       $10
FM11_IRQSTAT_PTM    EQU       $01
PTM_CTRL1           EQU       $FD39
PTM_STATUS          EQU       $FD39
PTM_COUNT1          EQU       $FD3C
PTM_CTRL_IRQ        EQU       $40
PTM_RELOAD          EQU       194
FM11_ROMCTL         EQU       $FD93
FM11_ROM_RAM        EQU       $01
UART_DATA           EQU       $FD06
UART_CTRL           EQU       $FD07
UART_TXRDY          EQU       $01
UART_RXRDY          EQU       $02
DPort               SET       $FD30
HW.Page             SET       $FD
                    ENDC

* FM-11 FDC registers used by the initial read-only /D0 driver.
FM11_FDC_CMD        EQU       $FD30
FM11_FDC_STATUS     EQU       $FD30
FM11_FDC_TRACK      EQU       $FD31
FM11_FDC_SECTOR     EQU       $FD32
FM11_FDC_DATA       EQU       $FD33
FM11_FDC_SIDE       EQU       $FD34
FM11_FDC_DRIVE      EQU       $FD35
FM11_FDC_AUX        EQU       $FD36
FM11_FDC_IRQSTAT    EQU       $FD37
FM11_FDC_DRQ        EQU       $02
FM11_FDC_ERRMASK    EQU       $90
FM11_FDC_READSEC    EQU       $80
FM11_FDC_WRITESEC   EQU       $A0
FM11_FDC_RESTORE    EQU       $00
FM11_FDC_WRITETRK   EQU       $F0
* FM-11 2D MiniFDC registers (2D0-2D3).
FM11_MFDC_CMD       EQU       $FD18
FM11_MFDC_STATUS    EQU       $FD18
FM11_MFDC_TRACK     EQU       $FD19
FM11_MFDC_SECTOR    EQU       $FD1A
FM11_MFDC_DATA      EQU       $FD1B
FM11_MFDC_SIDE      EQU       $FD1C
FM11_MFDC_DRIVE     EQU       $FD1D
FM11_MFDC_AUX       EQU       $FD1E
FM11_MFDC_IRQSTAT   EQU       $FD1F
FM11_MFDC_DRQ       EQU       $02
FM11_MFDC_ERRMASK   EQU       $90
FM11_MFDC_READSEC   EQU       $80
FM11_MFDC_WRITESEC  EQU       $A0
FM11_MFDC_RESTORE   EQU       $00
FM11_MFDC_WRITETRK  EQU       $F0
* FM-11 DMA channel 0 registers used by the 2D MiniFDC.
FM11_DMA0_ADDR_H    EQU       $FD94       20-bit address bits 19..16
FM11_DMA0_ADDR_M    EQU       $FD40       address bits 15..8
FM11_DMA0_ADDR_L    EQU       $FD41       address bits 7..0
FM11_DMA0_COUNT_H   EQU       $FD42
FM11_DMA0_COUNT_L   EQU       $FD43
FM11_DMA0_MODE      EQU       $FD50
* FM-11 DMA channel 1 registers used by the FDC.
FM11_DMA1_ADDR_H    EQU       $FD95       20-bit address bits 19..16
FM11_DMA1_ADDR_M    EQU       $FD44       address bits 15..8
FM11_DMA1_ADDR_L    EQU       $FD45       address bits 7..0
FM11_DMA1_COUNT_H   EQU       $FD46
FM11_DMA1_COUNT_L   EQU       $FD47
FM11_DMA1_MODE      EQU       $FD51

* FM-11 Magnetic Disk Controller (MDC) / hard disk interface.
FM11_MDC_CMD        EQU       $FDC0
FM11_MDC_STATUS     EQU       $FDC0
FM11_MDC_DATA       EQU       $FDC1
FM11_MDC_SELECT     EQU       $FDC2
FM11_MDC_AUX        EQU       $FDC3
FM11_MDC_SETCMASK   EQU       $11
FM11_MDC_READ       EQU       $22
FM11_MDC_WRITE      EQU       $23
* FM-11 DMA channel 2 used by the initial MDC hard-disk driver.
FM11_DMA2_ADDR_H    EQU       $FD96       20-bit address bits 19..16
FM11_DMA2_ADDR_M    EQU       $FD48       address bits 15..8
FM11_DMA2_ADDR_L    EQU       $FD49       address bits 7..0
FM11_DMA2_COUNT_H   EQU       $FD4A
FM11_DMA2_COUNT_L   EQU       $FD4B
FM11_DMA2_MODE      EQU       $FD52
FM11_DMA_DIR_WRITE  EQU       $01         memory -> disk
FM11_DMA_ENABLE     EQU       $04
FM11_DMA_ERROR      EQU       $40
FM11_DMA_DONE       EQU       $80

* FM-11 private SetStat services used for the reserved boot cylinder.
SS.FM11Boot         EQU       $90        * Cobbler: write S5.. boottrack
SS.FM11IPL          EQU       $91        * Format/Cobbler: write reserved ROM IPL slots
SS.FM11HDIPL        EQU       $92        * HDD: write physical sectors 0-1 ROM IPL
SS.FM11HDBoot       EQU       $93        * HDD: write physical sectors 2-18 Bootp1
* 2D: S1-S2 are ROM-loaded (2 x 256); S3-S4 stay reserved by the current
*     NitrOS-9 layout.  2HD: S1-S4 are ROM-loaded (4 x 128).
