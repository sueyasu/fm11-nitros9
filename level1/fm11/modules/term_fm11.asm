********************************************************************
* Term - Fujitsu FM-11 Local Console Device Descriptor
********************************************************************

                    nam       Term
                    ttl       FM-11 Local Console Device Descriptor

                    ifp1
                    use       defsfile
                    endc

FM11_SUB_CTRL       equ       $FD05

                    ifndef    Pauses
Pauses              equ       0
                    endif

tylg                set       Devic+Objct
atrv                set       ReEnt+rev
rev                 set       0

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       UPDAT.              mode byte
                    fcb       HW.Page             extended controller address
                    fdb       FM11_SUB_CTRL       physical controller address

                    fcb       initsize-*-1        initialization table size
                    fcb       DT.SCF              sequential character device
                    fcb       $00                 IT.UPC: upper/lower case
                    fcb       $01                 IT.BSO: destructive backspace
                    fcb       $00                 IT.DLO: delete line style
                    fcb       $01                 IT.EKO: echo enabled
                    fcb       $01                 IT.ALF: auto LF enabled
                    fcb       $00                 IT.NUL: nulls after EOL
                    fcb       Pauses              IT.PAU
                    fcb       25                  IT.PAG
                    fcb       C$BSP               IT.BSP
                    fcb       C$DEL               IT.DEL
                    fcb       C$CR                IT.EOR
                    fcb       C$EOF               IT.EOF
                    fcb       C$RPRT              IT.RPR
                    fcb       C$RPET              IT.DUP
                    fcb       C$PAUS              IT.PSC
                    fcb       C$INTR              IT.INT
                    fcb       C$QUIT              IT.QUT
                    fcb       C$BSP               IT.BSE
                    fcb       C$BELL              IT.OVF
                    fcb       PARNONE             IT.PAR
                    fcb       STOP1+WORD8+B9600   IT.BAU
                    fdb       name                IT.D2P
                    fcb       C$XON               IT.XON
                    fcb       C$XOFF              IT.XOFF
                    fcb       80                  IT.COL
                    fcb       25                  IT.ROW
                    fcb       $00                 IT.XTYP
initsize            equ       *

name                fcs       /Term/
mgrnam              fcs       /SCF/
drvnam              fcs       /fm11console/

                    emod
eom                 equ       *
                    end
