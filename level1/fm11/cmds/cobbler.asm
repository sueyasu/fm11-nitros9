********************************************************************
* Cobbler - Write OS9Boot to a disk
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   7      ????/??/??
* From Tandy OS-9 Level Two VR 02.00.01.
*
*          2002/07/20  Boisy G. Pitre
* Modified source to allow for OS-9 Level One and Level Two assembly.
*
*	   2005/11/03  P.Harvey-Smith.
* Added the ability to assemble for either CoCo or Dragon.
*
*        2011/09/13 Robert Gault
* Added support for DD.BIT cluster size.
* Removed hard coded FAT buffer and calculated the size from DD.BIT.
* Added error message if not enough memory for buffer.
* Moved common code into subroutine for CheckAlloc & Allocate.
*
*        2011/09/16 Robert Gault
* Corrected a typo which occured when committing code. Exit of Initcalc had
* ABM3 in wrong place.
*
*        2011/09/18 Robert Gault
* Cleaned up code and removed multiple calculations of shift divisor by
* calculating it once and storing it in data.
* Corrected sector count calculation to include partial clusters.
*
*        2014/12/09 Robert Gault
* Report fragmented OS9Boot as normal but suggest using -e option if
* used with modern Boot module that can handle fragmentation.

                    nam       Cobbler
                    ttl       Write OS9Boot to a disk

* Disassembled 02/07/06 13:08:41 by Disasm v1.6 (C) 1988 by RML

*The next line needed for stand-alone compiling. It should not
* be present in the NitrOS-9 project.

*Level    equ	2

                    ifp1
                    use       defsfile
                    endc

DOHELP              set       1

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       13

                    mod       eom,name,tylg,atrv,start,size

                    org       0
lsn0buff            rmb       26                  Buffer to hold data from LSN0 of traget device
newbpath            rmb       1
devpath             rmb       3
EndDevName          rmb       2                   pointer to last character of device name when moving to fullbnam
btshift             rmb       2                   division factor
bitflag             rmb       1                   indicates fractional division
fullbnam            rmb       20                  this buffer holds the entire name (i.e. /D0/OS9Boot)
u0034               rmb       16
BootBuf             rmb       7                   Area to read part of current boot area into, to check for boot stuff
u004B               rmb       2
LSNBitmapByte       rmb       1                   Saved byte from bitmap, of current LSN
u004E               rmb       16
pathopts            rmb       20
u0072               rmb       2
u0074               rmb       10
bffdbuf             rmb       16
u008E               rmb       1
u008F               rmb       7
u0096               rmb       232
eflag               rmb       1
bootloc             rmb       3
                    ifne      fm11
FMAssetPath         rmb       1
FMFileBuf           rmb       4352                17 x 256-byte Bootp1 image
                    endc
                    ifgt      Level-1
u057E               rmb       76
u05CA               rmb       8316
                    endc

bitmbuf             equ       .                   New flexible buffer R.G.
size                equ       .

name                fcs       /Cobbler/
                    fcb       edition

L0015               fcb       $00
                    fcb       $00

                    ifne      DOHELP
HelpMsg             fcb       C$LF
                    fcc       "Use: COBBLER </devname> [<opts>]"
                    fcb       C$LF
                    fcc       "     to create a new system disk"
                    fcb       C$LF
                    fcc       "-e = extended boot (fragmentation permitted)"
                    fcb       C$CR
                    endc
WritErr             fcb       C$LF
                    fcc       "Error writing kernel track"
                    fcb       C$CR
FMResetErr          fcb       C$LF
                    fcc       "Error resetting boot drive"
                    fcb       C$CR
FMIPLErr            fcb       C$LF
                    fcc       "Error writing IPL sectors"
                    fcb       C$CR
FMIPLNoRecErr       fcb       C$LF
                    fcc       "Error writing IPL sectors: Record Not Found"
                    fcb       C$CR
FMIPLNotReadyErr    fcb       C$LF
                    fcc       "Error writing IPL sectors: drive not ready"
                    fcb       C$CR
FMIPLDMAErrMsg      fcb       C$LF
                    fcc       "Error writing IPL sectors: DMA error"
                    fcb       C$CR
FMIPLDMAWaitMsg     fcb       C$LF
                    fcc       "Error writing IPL sectors: DMA incomplete"
                    fcb       C$CR
                    fcb       C$LF
                    fcc       "Error - cannot gen to hard disk"
                    fcb       C$CR
SeekErr             fcb       C$LF
                    fcc       "Error seeking sector"
                    fcb       C$CR
                    ifne      DRAGON
FileWarn            fcb       C$LF
                    fcc       "Warning - not a Dragon "
                    fcb       C$LF
                    fcc       "disk."

                    else
FileWarn            fcb       C$LF
                    fcc       "Warning - file(s) present"
                    fcb       C$LF
                    fcc       "on track 34 - this track"

                    endc

                    fcb       C$LF
                    fcc       "not rewritten."
                    fcb       C$CR
BootFrag            fcb       C$LF
                    fcc       "Error - OS9boot file fragmented"
                    fcb       C$LF
                    fcc       "try using 'cobbler /dev -e' with"
                    fcb       C$LF
                    fcc       "current NitrOS-9 systems."
                    fcb       C$CR
                    ifgt      Level-1
RelMsg              fcb       C$LF
                    fcc       "Error - can't link to Rel module"
                    fcb       C$CR
                    endc
BootName            fcc       "OS9Boot "
                    fcb       $FF
RelNam              fcc       "Rel"
                    fcb       $FF
                    ifne      fm11
FMTypeErr           fcb       C$LF
                    fcc       "Error - unsupported FM-11 target geometry"
                    fcb       C$CR
FMAssetErr          fcb       C$LF
                    fcc       "Error reading FM-11 IPL/Bootp1 file from /DD/SYS"
                    fcb       C$CR
FMIPL2DName         fcc       "/DD/SYS/IPL/IPL.2D"
                    fcb       C$CR
FMIPL2HDName        fcc       "/DD/SYS/IPL/IPL.2HD"
                    fcb       C$CR
FMBoot2DName        fcc       "/DD/SYS/BOOT/Bootp1.2D"
                    fcb       C$CR
FMBoot2HDName       fcc       "/DD/SYS/BOOT/Bootp1.2HD"
                    fcb       C$CR
FMIPLHDName          fcc       "/DD/SYS/IPL/IPL.HD"
                    fcb       C$CR
FMBootHDName         fcc       "/DD/SYS/BOOT/Bootp1.HD"
                    fcb       C$CR
                    endc
* This might happen if there is not enough memory present.
MemSpace            fcc       "There is not enough memory for buffer space"
                    fcb       C$CR

DragonRootSec       equ       $12                 Dragon root sector is always LSN 18

start               clrb                          Check first char is a /
                    stb       eflag,u
                    lda       #PDELIM
                    cmpa      ,x
                    lbne      ShowHelp

                    os9       F$PrsNam            Parse the name
                    lbcs      ShowHelp            Error : show help

                    lda       ,y
                    cmpa      #PDELIM             Check that path has only one / e.g. '/d1'
                    lbeq      ShowHelp            yes : show help

                    cmpa      #C$CR
                    beq       godoit
                    cmpa      #C$SPAC
                    lbne      ShowHelp
parseopt            lda       ,y+
                    cmpa      #'-
                    beq       parsein
                    cmpa      #C$CR
                    beq       godoit
                    bra       parseopt
parsein             lda       ,y+
                    anda      #$DF                make uppercase
                    cmpa      #'E                 extended boot
                    lbne      ShowHelp
                    inc       eflag,u             mark for fragmented boot
godoit              lda       #PDELIM
                    leay      <fullbnam,u         Transfer name to our buffer
L013C               sta       ,y+
                    lda       ,x+
                    decb
                    bpl       L013C

                    sty       <EndDevName         Save pointer to end of dev name
                    ldd       #PENTIR*256+C$SPAC  Store '@ ' at end of devname, for entire dev e.g. '/d1@ '
                    std       ,y++
                    leax      <fullbnam,u         Point to devname
                    lda       #UPDAT.             Open for update
                    os9       I$Open
                    sta       <devpath            Save pathnumber
                    lbcs      ShowHelp            Error opening dev, show help + exit

                    ifne      fm11
* Save target-device geometry now. pathopts is later reused for the
* newly-created OS9Boot file, so it cannot be used for media comparison.
                    leax      <pathopts,u
                    clrb                          SS.Opt
                    lda       <devpath
                    os9       I$GetStt
                    lbcs      Bye
                    ldd       <pathopts+(PD.CYL-PD.OPT),u
                    std       <u0034,u            target cylinders
                    ldd       <pathopts+(PD.SCT-PD.OPT),u
                    std       <u0034+2,u          target sectors/track
                    lda       <pathopts+(PD.SID-PD.OPT),u
                    sta       <u0034+10,u         target heads
                    clr       <u0034+12,u         0=2D,1=2HD,2=HDD
                    lda       <pathopts+(PD.TYP-PD.OPT),u
                    bita      #TYP.HARD
                    bne       FMGeomHD
                    ldd       <u0034,u
                    cmpd      #40
                    lbeq      FMGeom2D
                    cmpd      #77
                    lbne      FMTypeBad
                    ldd       <u0034+2,u
                    cmpd      #26
                    lbne      FMTypeBad
                    inc       <u0034+12,u
                    bra       FMGeomOK
FMGeom2D            ldd       <u0034+2,u
                    cmpd      #16
                    lbne      FMTypeBad
                    bra       FMGeomOK
FMGeomHD            ldd       <u0034+2,u
                    cmpd      #32
                    lbne      FMTypeBad
                    ldd       <u0034,u
                    cmpd      #157
                    lbeq      FMGeomHD157
                    cmpd      #315
                    lbeq      FMGeomHD315
                    cmpd      #747
                    lbne      FMTypeBad
                    lda       <u0034+10,u
                    cmpa      #4
                    lbeq      FMGeomHDOK
                    cmpa      #7
                    lbeq      FMGeomHDOK
                    cmpa      #11
                    lbne      FMTypeBad
                    lbra      FMGeomHDOK
FMGeomHD157         lda       <u0034+10,u
                    cmpa      #4
                    lbeq      FMGeomHDOK
                    cmpa      #6
                    lbne      FMTypeBad
                    lbra      FMGeomHDOK
FMGeomHD315         lda       <u0034+10,u
                    cmpa      #2
                    lbeq      FMGeomHDOK
                    cmpa      #4
                    lbeq      FMGeomHDOK
                    cmpa      #6
                    lbeq      FMGeomHDOK
                    cmpa      #8
                    lbne      FMTypeBad
FMGeomHDOK          lda       #2
                    sta       <u0034+12,u
FMGeomOK            equ       *
                    endc

                    ldx       <EndDevName         Get pointer to end of dev name
                    leay      >BootName,pcr       Get pointer to boot file name
                    lda       #PDELIM             Append path delimiter e.g. '/d1/'
L0162               sta       ,x+                 Append boot name to dev name e.g. '/d1/OS9Boot'
                    lda       ,y+
                    bpl       L0162

                    pshs      u
                    clra
                    clrb
                    tfr       d,x
                    tfr       d,u
                    lda       <devpath
                    os9       I$Seek              seek to 0
                    lbcs      Bye
                    puls      u
                    leax      lsn0buff,u          Point to buffer
                    ldy       #DD.DAT             $1A
                    lda       <devpath
                    os9       I$Read              read LSN0
                    lbcs      Bye                 Error : exit
                    lbsr      FShift              get divisor from DD.BIT R.G.
                    sty       btshift,u
* Request memory for the FAT buffer + 256 bytes for stack space R.G.
                    ldd       <DD.MAP
                    addd      #size+256
                    os9       F$Mem
                    lbcs      NoMem
                    tfr       y,s

                    ldd       <DD.BSZ             get size of bootfile currently
                    bne       delit               there is a size so assume file present
                    tst       eflag,u             no size but could be extended boot
                    beq       L019F               no eflag so probably no boot file

delit               leax      <fullbnam,u
                    os9       I$Delete            delete existing bootfile

                    clra
                    clrb
                    sta       <DD.BT              Init some of the LSN0 vars
                    std       <DD.BT+1
                    std       <DD.BSZ
                    lbsr      WriteLSN0           Write back to disk

L019F               lda       #WRITE.
                    ldb       #READ.+WRITE.
                    leax      <fullbnam,u
                    os9       I$Create            create new bootfile
                    sta       <newbpath           Save pathnumber
                    lbcs      Bye                 branch if error

                    ifgt      Level-1
* OS-9 Level Two: Copy first 90 bytes of system direct page into our space
* so we can figure out boot location and size, then copy to our space
                    leax      >L0015,pcr
                    tfr       x,d
                    ldx       #$0000
                    ldy       #$0090
                    pshs      u
                    leau      >u057E,u
                    os9       F$CpyMem
                    lbcs      Bye
                    puls      u
                    leax      >L0015,pcr
                    tfr       x,d
                    ldx       >u05CA,u
                    ldy       #$0010
                    pshs      u
                    leau      <u004E,u
                    os9       F$CpyMem
                    puls      u
                    lbcs      Bye
                    leax      >u057E,u
                    ldd       <D.BtPtr,x
                    pshs      b,a
                    ldd       <D.BtSz,x
                    std       <DD.BSZ
                    pshs      b,a
L01F7               ldy       #$2000
                    cmpy      ,s
                    bls       L0203
                    ldy       ,s
L0203               pshs      y
                    leax      <u004E,u
                    tfr       x,d
                    ldx       $04,s
                    pshs      u
                    leau      >u057E,u
                    os9       F$CpyMem
                    lbcs      Bye
                    puls      u
                    ldy       ,s
                    leax      >u057E,u
                    lda       <newbpath
                    os9       I$Write
                    lbcs      Bye
                    puls      b,a
                    ldy       $02,s
                    leay      d,y
                    sty       $02,s
                    nega
                    negb
                    sbca      #$00
                    ldy       ,s
                    leay      d,y
                    sty       ,s
                    bne       L01F7
                    leas      $04,s

                    else

* OS-9 Level One: Write out bootfile.
                    ifne      fm11
* FM-11 may generate a target profile different from the currently booted
* profile.  Copy the resident bootfile module-by-module and substitute only
* D0/D1/D2/D3/DD with the target-specific descriptor modules.
                    lbsr      FMWriteBootFile
                    lbcs      Bye
                    else
                    ldd       >D.BTHI             get bootfile size
                    subd      >D.BTLO
                    tfr       d,y                 in D, tfr to Y
                    std       <DD.BSZ             save it
                    ldx       >D.BTLO             get pointer to boot in mem
                    lda       <newbpath
                    os9       I$Write             write out boot to file
                    lbcs      Bye
                    endc

                    endc

                    leax      <pathopts,u         Point to option buffer
                    clrb                          Read option section of Path descriptor
*         ldb   #SS.Opt
                    lda       <newbpath           Get pathnumber of new bootfile
                    os9       I$GetStt            Get options
                    lbcs      Bye                 Error: exit

                    lda       <newbpath           Close bootfile
                    os9       I$Close

                    lbcs      ShowHelp
                    pshs      u
                    ldx       <pathopts+(PD.FD-PD.OPT),u
                    lda       <pathopts+(PD.FD+2-PD.OPT),u
* Now X and A hold file descriptor sector LSN of newly created OS9Boot
* Save this incase of fragmentation.
                    stx       bootloc,u
                    sta       bootloc+2,u
                    clrb
                    tfr       d,u
                    lda       <devpath
                    os9       I$Seek              seek to os9boot file descriptor
                    puls      u
                    lbcs      Bye                 Error: exit

                    leax      bffdbuf,u           Point to buffer for filedes sector
                    ldy       #256
                    os9       I$Read              read in filedes sector
                    lbcs      Bye                 Error: exit
                    ldd       >bffdbuf+(FD.SEG+FDSL.S+FDSL.B),u Test if fragmented
                    pshs      cc
                    tst       eflag,u
                    bne       extend
                    puls      cc
                    lbne      IsFragd             branch if fragmented
                    bra       notfragd
extend              puls      cc
                    beq       notfragd
                    ldb       bootloc,u
                    stb       <DD.BT
                    ldd       bootloc+1,u
                    std       <DD.BT+1
                    clra
                    clrb
                    std       <DD.BSZ
                    bra       sendit
notfragd            equ       *
* Get and save bootfile's LSN
                    ldb       >bffdbuf+(FD.SEG),u
                    stb       <DD.BT
                    ldd       >bffdbuf+(FD.SEG+1),u
                    std       <DD.BT+1
sendit              equ       *
                    lbsr      WriteLSN0           Write bootfile loc to LSN0 on disk

                    ifne      fm11
* FM-11: cylinder 0 is reserved outside the RBF bitmap.  The target
* descriptor, not /DD, selects the media profile.  This permits a 2D
* system to build 2HD media and vice versa.
                    lda       <devpath
                    ldb       #SS.Reset
                    os9       I$SetStt
                    lbcs      FMResetBad

                    lda       <u0034+12,u
                    cmpa      #2
                    beq       FMCobTargetHD
                    ldd       <u0034,u            target cylinders: 40=2D, 77=2HD
                    cmpd      #40
                    beq       FMCobTarget2D
                    cmpd      #77
                    lbne      FMTypeBad
                    ldd       <u0034+2,u
                    cmpd      #26
                    lbne      FMTypeBad
                    leax      >FMIPL2HDName,pcr
                    leay      >FMBoot2HDName,pcr
                    sty       <u0034+8,u
                    bra       FMCobWriteIPL
FMCobTargetHD       leax      >FMIPLHDName,pcr
                    leay      >FMBootHDName,pcr
                    sty       <u0034+8,u
                    ldy       #512
                    lbsr      FMReadAsset
                    lbcs      FMAssetBad
                    lda       <devpath
                    ldb       #SS.FM11HDIPL
                    os9       I$SetStt
                    lbcs      FMIPLBad
                    ldx       <u0034+8,u
                    ldy       #4352
                    lbsr      FMReadAsset
                    lbcs      FMAssetBad
                    lda       <devpath
                    ldb       #SS.FM11HDBoot
                    os9       I$SetStt
                    lbcs      WriteBad
                    bra       FMCobClose
FMCobTarget2D       ldd       <u0034+2,u
                    cmpd      #16
                    lbne      FMTypeBad
                    leax      >FMIPL2DName,pcr
                    leay      >FMBoot2DName,pcr
                    sty       <u0034+8,u
FMCobWriteIPL       ldy       #1024
                    lbsr      FMReadAsset
                    lbcs      FMAssetBad
                    lda       <devpath
                    ldb       #SS.FM11IPL
                    os9       I$SetStt
                    lbcs      FMIPLBad

                    ldx       <u0034+8,u          matching /DD/SYS/BOOT pathname
                    ldy       #4352               17 physical 256-byte sectors
                    lbsr      FMReadAsset
                    lbcs      FMAssetBad
                    lda       <devpath
                    ldb       #SS.FM11Boot
                    os9       I$SetStt
                    lbcs      WriteBad
FMCobClose          lda       <devpath
                    os9       I$Close
                    lbcs      Bye

* FM-11: all target writes are complete and the target path is closed.
* RBSuper Term now returns its cache with the correct 16-bit size, so there is
* no need to force an external RESET after a successful Cobbler operation.
                    clrb
                    lbra      Bye

FMTypeBad           leax      >FMTypeErr,pcr
                    clrb
                    lbra      DisplayErrorAndExit
FMAssetBad          leax      >FMAssetErr,pcr
                    lbra      DisplayErrorAndExit

FMResetBad          leax      >FMResetErr,pcr
                    clrb
                    lbra      DisplayErrorAndExit
FMIPLBad            cmpb      #$10                FDC Record Not Found
                    beq       FMIPLNoRecord
                    cmpb      #$80                FDC Not Ready
                    beq       FMIPLNotReady
                    cmpb      #$01                llfm11 diagnostic: DMA error
                    beq       FMIPLDMAErr
                    cmpb      #$02                llfm11 diagnostic: DMA incomplete
                    beq       FMIPLDMAWait
                    leax      >FMIPLErr,pcr
                    clrb
                    lbra      DisplayErrorAndExit
FMIPLNoRecord       leax      >FMIPLNoRecErr,pcr
                    clrb
                    lbra      DisplayErrorAndExit
FMIPLNotReady       leax      >FMIPLNotReadyErr,pcr
                    clrb
                    lbra      DisplayErrorAndExit
FMIPLDMAErr         leax      >FMIPLDMAErrMsg,pcr
                    clrb
                    lbra      DisplayErrorAndExit
FMIPLDMAWait        leax      >FMIPLDMAWaitMsg,pcr
                    clrb
                    lbra      DisplayErrorAndExit

********************************************************************
* FMWriteBootFile
*
* Level 1 keeps the resident OS9Boot image between D.BTLO and D.BTHI.
* Copy it module by module, replacing only the five logical floppy
* descriptors with the versions required by the target media profile.
* This preserves the running system's kernel/managers/drivers while making
* /D0-/D3 and /DD correct for a 2D or 2HD target independently of /DD.
********************************************************************
FMWriteBootFile     ldx       >D.BTLO
                    stx       <u0034+4,u          current source module
                    ldx       >D.BTHI
                    stx       <u0034+6,u          end of resident bootfile
                    clra
                    clrb
                    std       <DD.BSZ
FMWBLoop            ldx       <u0034+4,u
                    cmpx      <u0034+6,u
                    lbhs      FMWBDone
                    ldd       M$Size,x
                    leay      d,x
                    sty       <u0034+4,u          next resident module
                    lbsr      FMSelectDesc
                    ldy       M$Size,x
                    pshs      y
                    lda       <newbpath
                    os9       I$Write
                    puls      y
                    lbcs      FMWBExit
                    tfr       y,d
                    addd      <DD.BSZ
                    std       <DD.BSZ
                    lbra      FMWBLoop
FMWBDone            clrb
                    andcc     #^Carry
FMWBExit            rts

* Input X = resident module.  Return X = module to write.
* Exact FM-11 boot descriptors D0/D1/D2/D3/DD/H0 are replaced for the target media.
FMSelectDesc        pshs      d,y
                    ldd       M$Name,x
                    leay      d,x
                    lda       ,y
                    cmpa      #$44                'D'
                    beq       FMSelNameD
                    cmpa      #$48                'H'
                    lbne      FMSelDone
                    lda       1,y
                    cmpa      #$B0                '0' with FCS high bit
                    lbeq      FMSelH0
                    lbra      FMSelDone
FMSelNameD          lda       1,y
                    cmpa      #$B0                '0' with FCS high bit
                    lbeq      FMSelD0
                    cmpa      #$B1
                    lbeq      FMSelD1
                    cmpa      #$B2
                    lbeq      FMSelD2
                    cmpa      #$B3
                    lbeq      FMSelD3
                    cmpa      #$C4                'D' with FCS high bit
                    lbeq      FMSelDD
                    lbra      FMSelDone

FMSelH0             lda       <u0034+12,u
                    cmpa      #2
                    lbne      FMSelDone
                    ldd       <u0034,u
                    cmpd      #157
                    lbeq      FMSelH0_157
                    cmpd      #315
                    lbeq      FMSelH0_315
                    leax      >FM11H0_M2241,pcr
                    lda       <u0034+10,u
                    cmpa      #4
                    lbeq      FMSelDone
                    leax      >FM11H0_M2242,pcr
                    cmpa      #7
                    lbeq      FMSelDone
                    leax      >FM11H0_M2243,pcr
                    lbra      FMSelDone
FMSelH0_157         leax      >FM11H0_M2231,pcr
                    lda       <u0034+10,u
                    cmpa      #4
                    lbeq      FMSelDone
                    leax      >FM11H0_M2232,pcr
                    lbra      FMSelDone
FMSelH0_315         leax      >FM11H0_M2230,pcr
                    lda       <u0034+10,u
                    cmpa      #2
                    lbeq      FMSelDone
                    leax      >FM11H0_M2233,pcr
                    cmpa      #4
                    lbeq      FMSelDone
                    leax      >FM11H0_M2234,pcr
                    cmpa      #6
                    lbeq      FMSelDone
                    leax      >FM11H0_M2235,pcr
                    lbra      FMSelDone

FMSelD0             lda       <u0034+12,u
                    cmpa      #2
                    lbeq      FMSelDone
                    ldd       <u0034,u
                    cmpd      #40
                    lbeq      FMSelD0_2D
                    leax      >FM11D0_2HD,pcr
                    lbra      FMSelDone
FMSelD0_2D          leax      >FM11D0_2D,pcr
                    lbra      FMSelDone
FMSelD1             lda       <u0034+12,u
                    cmpa      #2
                    lbeq      FMSelDone
                    ldd       <u0034,u
                    cmpd      #40
                    lbeq      FMSelD1_2D
                    leax      >FM11D1_2HD,pcr
                    lbra      FMSelDone
FMSelD1_2D          leax      >FM11D1_2D,pcr
                    lbra      FMSelDone
FMSelD2             lda       <u0034+12,u
                    cmpa      #2
                    lbeq      FMSelDone
                    ldd       <u0034,u
                    cmpd      #40
                    lbeq      FMSelD2_2D
                    leax      >FM11D2_2HD,pcr
                    lbra      FMSelDone
FMSelD2_2D          leax      >FM11D2_2D,pcr
                    lbra      FMSelDone
FMSelD3             lda       <u0034+12,u
                    cmpa      #2
                    lbeq      FMSelDone
                    ldd       <u0034,u
                    cmpd      #40
                    lbeq      FMSelD3_2D
                    leax      >FM11D3_2HD,pcr
                    lbra      FMSelDone
FMSelD3_2D          leax      >FM11D3_2D,pcr
                    lbra      FMSelDone
FMSelDD             lda       <u0034+12,u
                    cmpa      #2
                    lbeq      FMSelDD_HD
                    ldd       <u0034,u
                    cmpd      #40
                    lbeq      FMSelDD_2D
                    leax      >FM11DD_2HD,pcr
                    lbra      FMSelDone
FMSelDD_HD          ldd       <u0034,u
                    cmpd      #157
                    lbeq      FMSelDD_157
                    cmpd      #315
                    lbeq      FMSelDD_315
                    leax      >FM11DD_M2241,pcr
                    lda       <u0034+10,u
                    cmpa      #4
                    lbeq      FMSelDone
                    leax      >FM11DD_M2242,pcr
                    cmpa      #7
                    lbeq      FMSelDone
                    leax      >FM11DD_M2243,pcr
                    lbra      FMSelDone
FMSelDD_157         leax      >FM11DD_M2231,pcr
                    lda       <u0034+10,u
                    cmpa      #4
                    lbeq      FMSelDone
                    leax      >FM11DD_M2232,pcr
                    lbra      FMSelDone
FMSelDD_315         leax      >FM11DD_M2230,pcr
                    lda       <u0034+10,u
                    cmpa      #2
                    lbeq      FMSelDone
                    leax      >FM11DD_M2233,pcr
                    cmpa      #4
                    lbeq      FMSelDone
                    leax      >FM11DD_M2234,pcr
                    cmpa      #6
                    lbeq      FMSelDone
                    leax      >FM11DD_M2235,pcr
                    lbra      FMSelDone
FMSelDD_2D          leax      >FM11DD_2D,pcr
FMSelDone           puls      d,y,pc

                    else
                    ldd       #$0001
                    lbsr      Seek2LSN
                    leax      >bitmbuf,u          Point to bitmap buffer
                    ldy       <DD.MAP             Get block number of map
                    lda       <devpath            Get dev pathnumber
                    os9       I$Read              read bitmap sector(s)
                    lbcs      Bye                 Error: exit

*
* On the dragon, we do not need to test to see if the boot track has files on
* as the boot area is on track 0 imediatly after the blockmap, and before
* the root directory, and therefore can never have files on it.
* However, we do need to verify that this is a Dragon formatted disk,
* we do this by checking that the root directory starts at LSN 18 (or greater).
*
                    ifne      DRAGON
                    ldd       <DD.DIR+1           Get LSN of root dir
                    cmpd      #DragonRootSec      Is this a dragon disk ?
                    beq       RewriteBitmap       Yes : write boot
                    lbra      TrkAlloc            No : error and exit.
                    else

                    ldd       #(Bt.Track*256)+Bt.Sec Get offset of boot track
                    ldy       #$0004              Check 4 csectors
                    lbsr      CheckAlloc
                    bcc       L0304               Not allocated, check rest

                    ldd       #(Bt.Track*256)+Bt.Sec Get offset of boot track
                    lbsr      Seek2LSN
                    leax      <BootBuf,u          Point to buffer
                    ldy       #$0007              No of bytes to read
                    lda       <devpath            Get device path
                    os9       I$Read              Do read
                    lbcs      Bye                 Error : exit

                    leax      <BootBuf,u          Point to buffer
                    ldd       ,x                  Load first 2 bytes into D
                    cmpa      #'O                 Check for presense of 'OS'
                    lbne      TrkAlloc            No: Try and allocate track (CoCo)
                    cmpb      #'S
                    lbne      TrkAlloc            No: Try and allocate track (CoCo)

                    lda       $04,x               Check 5th byte is a NOP
                    cmpa      #$12
                    beq       L02F7               Yes: boot track already contains boot code

                    ldd       #(Bt.Track*256)+Bt.Sec+$0F
                    ldy       #$0003
                    lbsr      CheckAlloc
                    lbcs      TrkAlloc

L02F7               clra                          Allocate boot track (CoCo)
                    ldb       <DD.TKS
                    tfr       d,y
                    ldd       #(Bt.Track*256)+Bt.Sec
                    lbsr      Allocate
                    bra       RewriteBitmap

L0304               ldd       #(Bt.Track*256)+Bt.Sec+$04 Check to see if sectors 5..18 of boot track free
                    ldy       #$000E              Number of sectors
                    lbsr      CheckAlloc          Check them
                    lbcs      TrkAlloc            Carry set, sectors allocated, error & exit
                    bra       L02F7

                    endc

RewriteBitmap
                    ldd       #$0001
                    lbsr      Seek2LSN            Seek to bitmap sector on disk
                    leax      >bitmbuf,u
                    ldy       <DD.MAP
                    lda       <devpath
                    os9       I$Write             write updated bitmap
                    lbcs      Bye

                    ifgt      Level-1
* OS-9 Level Two: Link to Rel, which brings in boot code
                    pshs      u
                    lda       #Systm+Objct
                    leax      >RelNam,pcr
                    os9       F$Link
                    lbcs      NoRel
                    tfr       u,d                 tfr module header to D
                    puls      u                   get statics ptr
                    subd      #$0006
                    std       <u004B,u            save pointer
                    lda       #$E0
                    anda      <u004B,u
                    ora       #$1E
                    ldb       #$FF
                    subd      <u004B,u
                    addd      #$0001
                    tfr       d,y
                    ldd       #(Bt.Track*256)+Bt.Sec
                    lbsr      Seek2LSN
                    lda       <devpath
                    ldx       <u004B,u

                    else

* OS-9 Level One: Write out data at $EF00
                    ldd       #(Bt.Track*256)+Bt.Sec Seek to boot track
                    lbsr      Seek2LSN
                    lda       <devpath
                    ldx       #Bt.Start           Get boot start and size
                    ldy       #Bt.Size

                    endc

                    os9       I$Write             Write boot track
                    lbcs      WriteBad            Error
                    os9       I$Close             Close devpath
                    lbcs      Bye                 Error : exit
                    clrb                          Flag no error
                    lbra      Bye
                    endc

* Get absolute LSN
* regA=track, regB=sector
* Returns in D
AbsLSN              pshs      b
                    ldb       <DD.FMT             get format byte
                    andb      #$01                check how many sides?
                    beq       L037F               branch if 1
                    ldb       #$02                else assume 2
                    bra       L0381
L037F               ldb       #$01
L0381               mul
                    lda       <DD.TKS             sectors per track
                    mul
                    addb      ,s+
                    adca      #$00
                    rts

* Determine bit shift from DD.BIT
* Return shift in regY needed for division R.G.
FShift              pshs      d
                    ldd       lsn0buff+DD.BIT,u   get sectors per cluster
                    ldy       #-1
* This finds number of bit shifts for DD.BIT
SF1                 lsra
                    rorb
                    leay      1,y
                    cmpd      #0
                    bne       SF1
                    puls      d,pc

* Enter: regD=LSN to test,regX=bitmap buffer
* Exit: regX points to bitmap byte of our LSN
*       regA=bit mask, regB not preserved
GetBitmapBit
* We need to divide by DD.BITx8 R.G.
                    pshs      y,d
                    ldy       btshift,u
                    cmpy      #0
                    beq       GBB3
* Divide LSN by DD.BIT
GBB2                lsra
                    rorb
                    leay      -1,y
                    bne       GBB2
GBB3                stb       ,s                  save lsb
                    andb      #7                  Make sure offset within table
                    stb       1,s                 save table mask
                    ldy       #3
* Now regY is the number of right shifts required for 8
                    ldb       ,s                  recover the lsb
GBB4                lsra
                    rorb
                    leay      -1,y
                    bne       GBB4
* Now regD is the byte number in the FAT
                    leax      d,x                 point regX at the byte
                    puls      d
                    leay      <BitTable,pcr       Point to bit table
                    lda       b,y                 Get bit from table
                    puls      pc,y                Restore regY and return

BitTable            fcb       $80,$40,$20,$10,$08,$04,$02,$01 Bitmap bit table

* Common code for CheckAlloc & Allocate moved to subroutine R.G.
* Enter: see CheckAlloc & Allocate
* Exit: regY=divisor, regD=LSN
Initcalc            bsr       AbsLSN              go get absolute LSN in D
                    leax      >bitmbuf,u          point X to our bitmap buffer
                    lbsr      GetBitmapBit        regA is bit from table
* New code to obtain a shift value R.G.
                    pshs      d,y
                    ldy       btshift,u
                    cmpy      #0
                    bne       CA2
                    puls      d,y,pc
CA2                 ldd       2,s                 recover number of sectors
                    clr       bitflag,u
* Divide sector count by DD.BIT
CAloop              lsra
                    rorb
                    bcc       CAlp2
                    inc       bitflag,u           indicate fractional result
CAlp2               leay      -1,y
                    bne       CAloop
                    tst       bitflag,u
                    beq       CAnz
                    incb                          include partial cluster
CAnz                tfr       d,y                 regY has been divided by DD.BIT
                    ldd       ,s                  recover content
                    leas      4,s                 clean stack
                    rts

*
* CheckAlloc, check to see if a block of sectors is allocated.
*
* Entry : A=track, B= sector, Y=number of sectors
* Exit : Carry Set, sectors are already allocated. Carry clear, sectors are free.
*
* I think regY needs to be divided by DD.BIT R.G.
CheckAlloc
                    pshs      y,x,b,a
                    lbsr      Initcalc
* Back to older code
                    sta       ,-s                 save off
                    bmi       L03CB

                    lda       ,x                  Get bitmap byte of our LSN
                    sta       <LSNBitmapByte      Save for later use
L03BB               anda      ,s                  Is our LSN allocated ?
                    bne       L03F7               Yes : flag error

                    leay      -$01,y              Decrement sector count
                    beq       L03F3               All done : yes, exit

                    lda       <LSNBitmapByte      Get saved bitmap byte
                    lsr       ,s                  Check next sector
                    bcc       L03BB               If carry, we need to fetch next byte from bitmap

                    leax      $01,x               Increment bitmap pointer
L03CB               lda       #$FF
                    sta       ,s
                    bra       L03DB

L03D1               lda       ,x
                    anda      ,s
                    bne       L03F7

                    leax      $01,x
                    leay      -$08,y
L03DB               cmpy      #$0008              Done a whole byte's worth of blocks ?
                    bhi       L03D1               Yes
                    beq       L03ED

                    lda       ,s                  Fetch current bit
L03E5               lsra                          Process next sector
                    leay      -$01,y              decrement sector count
                    bne       L03E5               Any more : yes continue

                    coma
                    sta       ,s
L03ED               lda       ,x
                    anda      ,s
                    bne       L03F7

L03F3               andcc     #^Carry
                    bra       L03F9

L03F7               orcc      #Carry              Flag error ?
L03F9               leas      $01,s               Drop saved byte
                    puls      pc,y,x,b,a          Restore and return


*
* Allocate, allocate blocks in bitmap
* Entry : A=track, B=sector, Y=block count.
*
* I think regY should be divided by DD.BIT R.G.
Allocate
                    pshs      y,x,b,a
                    lbsr      Initcalc
* Back to old code
                    sta       ,-s                 Save it
                    bmi       L041C

                    lda       ,x
L040E               ora       ,s
                    leay      -$01,y
                    beq       L043A

                    lsr       ,s
                    bcc       L040E

                    sta       ,x
                    leax      $01,x
L041C               lda       #$FF
                    bra       L0426

L0420               sta       ,x
                    leax      $01,x
                    leay      -$08,y
L0426               cmpy      #$0008
                    bhi       L0420
                    beq       L043A
L042E               lsra
                    leay      -$01,y
                    bne       L042E

                    coma
                    sta       ,s
                    lda       ,x
                    ora       ,s
L043A               sta       ,x
                    leas      $01,s
                    puls      pc,y,x,b,a

*
* Seek To LSN, A=track, B=sector
*

Seek2LSN            pshs      u,y,x,b,a
                    lbsr      AbsLSN
                    pshs      a
                    tfr       b,a
                    clrb
                    tfr       d,u
                    puls      b
                    clra
                    tfr       d,x
                    lda       <devpath
                    os9       I$Seek
                    bcs       SeekBad
                    puls      pc,u,y,x,b,a

WriteLSN0
                    pshs      u                   added for OS-9 Level One +BGP+
                    clra
                    clrb
                    tfr       d,x
                    tfr       d,u
                    lda       <devpath
                    os9       I$Seek              Seek to LSN0

                    puls      u                   added for OS-9 Level One +BGP+
                    leax      lsn0buff,u          Point to our LSN buffer
                    ldy       #DD.DAT
                    lda       <devpath
                    os9       I$Write             Write to disk
                    bcs       Bye                 branch if error
                    rts

ShowHelp            equ       *
                    ifne      DOHELP
                    leax      >HelpMsg,pcr
                    else
                    clrb
                    bra       Bye
                    endc

DisplayErrorAndExit
                    pshs      b
                    lda       #$02
                    ldy       #256
                    os9       I$WritLn
                    comb
                    puls      b
Bye                 os9       F$Exit

IsFragd             leax      >BootFrag,pcr
                    clrb
                    bra       DisplayErrorAndExit

WriteBad            leax      >WritErr,pcr
                    clrb
                    bra       DisplayErrorAndExit
SeekBad             leax      SeekErr,pcr
                    clrb
                    lbsr      DisplayErrorAndExit
TrkAlloc            leax      >FileWarn,pcr
                    clrb
                    bra       DisplayErrorAndExit

NoMem               leax      >MemSpace,pcr
                    clrb
                    bra       DisplayErrorAndExit

                    ifgt      Level-1
NoRel               leax      >RelMsg,pcr
                    bra       DisplayErrorAndExit
                    endc

                    ifne      fm11
********************************************************************
* FMReadAsset - read an external FM-11 IPL/Bootp1 file into FMFileBuf.
* Entry: X = CR-terminated pathname, Y = requested byte count.
* Exit:  X = FMFileBuf, C clear on success; B = OS-9 error on failure.
********************************************************************
FMReadAsset         pshs      y
                    lda       #READ.
                    os9       I$Open
                    bcs       FMRAOpenFail
                    sta       >FMAssetPath,u
                    leax      >FMFileBuf,u
                    puls      y
                    os9       I$Read
                    bcs       FMRAReadFail
                    lda       >FMAssetPath,u
                    os9       I$Close
                    bcs       FMRAExit
                    leax      >FMFileBuf,u
                    clrb
                    andcc     #^Carry
FMRAExit            rts
FMRAOpenFail        leas      2,s
                    orcc      #Carry
                    rts
FMRAReadFail        pshs      b
                    lda       >FMAssetPath,u
                    os9       I$Close
                    puls      b
                    orcc      #Carry
                    rts
                    endc

********************************************************************
* FM-11 target-profile descriptor data embedded by build-minimal.sh.
* IPL and Bootp1 data are external files under /DD/SYS.  Cobbler retains
* only the logical descriptors needed to generate a target-profile OS9Boot.
********************************************************************
                    ifne      fm11
FM11D0_2D
                    use       cobbler-d0-2d.asm
FM11D1_2D
                    use       cobbler-d1-2d.asm
FM11D2_2D
                    use       cobbler-d2-2d.asm
FM11D3_2D
                    use       cobbler-d3-2d.asm
FM11DD_2D
                    use       cobbler-dd-2d.asm
FM11D0_2HD
                    use       cobbler-d0-2hd.asm
FM11D1_2HD
                    use       cobbler-d1-2hd.asm
FM11D2_2HD
                    use       cobbler-d2-2hd.asm
FM11D3_2HD
                    use       cobbler-d3-2hd.asm
FM11DD_2HD
                    use       cobbler-dd-2hd.asm
FM11H0_M2231
                    use       cobbler-h0-m2231b.asm
FM11DD_M2231
                    use       cobbler-dd-m2231b.asm
FM11H0_M2230
                    use       cobbler-h0-m2230b.asm
FM11DD_M2230
                    use       cobbler-dd-m2230b.asm
FM11H0_M2232
                    use       cobbler-h0-m2232b.asm
FM11DD_M2232
                    use       cobbler-dd-m2232b.asm
FM11H0_M2233
                    use       cobbler-h0-m2233b.asm
FM11DD_M2233
                    use       cobbler-dd-m2233b.asm
FM11H0_M2234
                    use       cobbler-h0-m2234b.asm
FM11DD_M2234
                    use       cobbler-dd-m2234b.asm
FM11H0_M2235
                    use       cobbler-h0-m2235b.asm
FM11DD_M2235
                    use       cobbler-dd-m2235b.asm
FM11H0_M2241
                    use       cobbler-h0-m2241b.asm
FM11DD_M2241
                    use       cobbler-dd-m2241b.asm
FM11H0_M2242
                    use       cobbler-h0-m2242b.asm
FM11DD_M2242
                    use       cobbler-dd-m2242b.asm
FM11H0_M2243
                    use       cobbler-h0-m2243b.asm
FM11DD_M2243
                    use       cobbler-dd-m2243b.asm
                    endc

                    emod
eom                 equ       *
                    end
