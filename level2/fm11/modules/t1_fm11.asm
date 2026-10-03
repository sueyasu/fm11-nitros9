********************************************************************
* T1 - FM-11 Level 2 USART0 device descriptor
********************************************************************

                    nam       T1
                    ttl       FM-11 Level 2 USART0 descriptor

                    ifp1
                    use       defsfile
                    endc

                    ifndef    Pauses
Pauses              equ       0
                    endc

tylg                set       Devic+Objct
atrv                set       ReEnt+rev
rev                 set       0

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       UPDAT.
                    fcb       HW.Page
                    fdb       UART_DATA

                    fcb       initsize-*-1
                    fcb       DT.SCF
                    fcb       $00
                    fcb       $01
                    fcb       $00
                    fcb       $01
                    fcb       $01
                    fcb       $00
                    fcb       Pauses
                    fcb       25
                    fcb       C$BSP
                    fcb       C$DEL
                    fcb       C$CR
                    fcb       C$EOF
                    fcb       C$RPRT
                    fcb       C$RPET
                    fcb       C$PAUS
                    fcb       C$INTR
                    fcb       C$QUIT
                    fcb       C$BSP
                    fcb       C$BELL
                    fcb       PARNONE
                    fcb       STOP1+WORD8+B9600
                    fdb       name
                    fcb       C$XON
                    fcb       C$XOFF
                    fcb       80
                    fcb       25
                    fcb       $00
initsize            equ       *

name                fcs       /T1/
mgrnam              fcs       /SCF/
drvnam              fcs       /fm11serial/

                    emod
eom                 equ       *
                    end
