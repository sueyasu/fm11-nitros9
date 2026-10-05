********************************************************************
* FM11Idle - minimal Level 2 user SWI2/F$Exit test
*
* Issue F$Exit immediately from user state with a distinctive status.
* The parent-side systest verifies the returned PID/status with F$Wait.
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
                    os9       F$ID

FM11IdleReturned    bra       FM11IdleReturned

                    emod
eom                 equ       *
                    end
