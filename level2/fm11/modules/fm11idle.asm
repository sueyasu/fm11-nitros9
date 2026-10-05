********************************************************************
* FM11Idle - minimal Level 2 user-state execution test
*
* Deliberately performs no OS-9 calls and no I/O.  Once F$NProc enters
* this module, it stays in user state until an interrupt occurs.
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
                    bra       start

                    emod
eom                 equ       *
                    end
