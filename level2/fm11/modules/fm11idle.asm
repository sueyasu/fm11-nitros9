********************************************************************
* FM11Idle - minimal Level 2 user-entry test
*
* Print directly to the FM-11 USART before issuing any system call.
* Reaching this message proves that the scheduler/MMU/trampoline path
* actually transferred execution into the user task.
********************************************************************

                    nam       FM11Idle
                    ttl       FM-11 Level 2 minimal user-state test

                  IFP1
                    use       defsfile
                  ENDC

tylg                set       Prgrm+Objct
atrv                set       ReEnt+0
edition             set       1

                    mod       eom,name,tylg,atrv,start,size

                    org       0
                    rmb       256
size                equ       .

name                fcs       /FM11Idle/
                    fcb       edition

start
                    leax      >FM11IdleMsg,pcr
FM11IdlePutS        lda       ,x+
                    beq       FM11IdleReturned
FM11IdlePutWait     ldb       >UART_CTRL
                    bitb      #UART_TXRDY
                    beq       FM11IdlePutWait
                    sta       >UART_DATA
                    bra       FM11IdlePutS

FM11IdleReturned    bra       FM11IdleReturned

FM11IdleMsg         fcc       /USER TASK RUNNING/
                    fcb       $0D,$0A,$00

                    emod
eom                 equ       *
                    end
