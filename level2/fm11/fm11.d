                    IFNE      FM11.D-1

FM11.D              SET       1

********************************************************************
* FM-11 Level 2 definitions
*
* NitrOS-9 keeps the standard Level 2 8 KiB DAT abstraction.  The
* hardware backend expands each 8 KiB block into two consecutive 4 KiB
* FM-11 MMR pages.
********************************************************************

Color               SET       1
CPUType             SET       Color
TkPerSec            SET       50
PwrLnFrq            SET       50
SHIFTBIT            EQU       %00000001

********************************************************************
* Level 2 kernel-track placement
*
*   $EA00-$EB2F  REL   ($0130)
*   $EB30-$EC7F  Boot  ($0150 slot)
*   $EC80-$FBFF  Krn   ($0F80 slot maximum)
*   $FC00-$FFFF  CPU-card fixed area
********************************************************************

Bt.Start            EQU       $EA00
Bt.Size             EQU       $1200

********************************************************************
* FM-11 hardware MMR
********************************************************************

FM11_MMR_BASE       EQU       $FD80
FM11_MMR_TASK       EQU       $FD90
FM11_MMR_CTRL       EQU       $FD93
FM11_MMR_ENABLE     EQU       $80
FM11_ROM_RAM        EQU       $01
FM11_MMR_PAGES      EQU       16

FM11_ROMCTL         EQU       FM11_MMR_CTRL

********************************************************************
* NitrOS-9 Level 2 DAT geometry
********************************************************************

DAT.BlCt            EQU       8
DAT.BlSz            EQU       $2000
DAT.ImSz            EQU       DAT.BlCt*2
DAT.Addr            EQU       -(DAT.BlSz/256)

* These names are retained for common-source assembly.  Direct FM-11
* hardware manipulation must use the backend/trampoline because one
* DAT entry expands to two hardware registers.
DAT.Task            EQU       FM11_MMR_TASK
DAT.Regs            EQU       FM11_MMR_BASE

* NitrOS-9 software task allocation is independent of the initial
* hardware task-0/task-1 bring-up policy.
DAT.TkCt            EQU       32

DAT.BlMx            EQU       $7F
DAT.BMSz            EQU       $80
DAT.Free            EQU       $33FF
DAT.WrPr            EQU       0
DAT.WrEn            EQU       0

SysTask             EQU       0
IOBlock             EQU       $7F
ROMBlock            EQU       $7F
IOAddr              EQU       $7F
ROMCount            EQU       1
RAMCount            EQU       1
MoveBlks            EQU       DAT.BlCt-ROMCount-2
BlockTyp            EQU       1
ByteType            EQU       2
Limited             EQU       1
UnLimitd            EQU       2
RAMCheck            EQU       BlockTyp
ROMCheck            EQU       Limited
LastRAM             EQU       DAT.BlMx
MappedIO            EQU       true

* Task-0 identity mapping places the kernel's 8 KiB block at physical
* pages $0E/$0F.
KrnBlk              SET       $07

********************************************************************
* Fixed CPU-card RAM trampoline
********************************************************************

FM11_L2_TRAMP        EQU       $FE00
FM11_L2_SWI3         EQU       $FE00
FM11_L2_SWI2         EQU       $FE08
FM11_L2_FIRQ         EQU       $FE10
FM11_L2_IRQ          EQU       $FE18
FM11_L2_SWI          EQU       $FE20
FM11_L2_NMI          EQU       $FE28
FM11_L2_STATE        EQU       $FEC0
FM11_L2_SWISTACK     EQU       $FEE0
FM11_L2_RETUSR       EQU       $FF00
FM11_L2_JMPUSR       EQU       $FF20
FM11_L2_RTIUSR       EQU       $FF28
FM11_L2_RTIMASK      EQU       $FF30
FM11_L2_DATBUF       EQU       $FF40
FM11_L2_SETTASK      EQU       $FF60
FM11_L2_FLIP0        EQU       $FFA0
FM11_L2_TRAMP_END    EQU       $FFF0

********************************************************************
* Console / timer
********************************************************************

UART_DATA           EQU       $FD06
UART_CTRL           EQU       $FD07
UART_TXRDY          EQU       $01
UART_RXRDY          EQU       $02

FM11_IRQEN          EQU       $FD02
FM11_IRQSTAT        EQU       $FD03
FM11_IRQ_PTM        EQU       $10
FM11_IRQSTAT_PTM    EQU       $01
PTM_CTRL1           EQU       $FD39
PTM_STATUS          EQU       $FD39
PTM_COUNT1          EQU       $FD3C
PTM_CTRL_IRQ        EQU       $40
PTM_RELOAD          EQU       194

********************************************************************
* 2D MiniFDC and DMA channel 0
********************************************************************

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

FM11_DMA0_ADDR_H    EQU       $FD94
FM11_DMA0_ADDR_M    EQU       $FD40
FM11_DMA0_ADDR_L    EQU       $FD41
FM11_DMA0_COUNT_H   EQU       $FD42
FM11_DMA0_COUNT_L   EQU       $FD43
FM11_DMA0_MODE      EQU       $FD50
FM11_DMA_ENABLE     EQU       $04
FM11_DMA_ERROR      EQU       $40
FM11_DMA_DONE       EQU       $80

DPort               SET       $FD30
HW.Page             SET       $FD

                    ENDC
