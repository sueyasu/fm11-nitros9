********************************************************************
* Piper - NitrOS-9 Level 1 null pipe device driver
*
* Pipes have no physical controller.  PipeMan performs the actual FIFO
* transfer; this driver supplies the device layer required by IOMan.
********************************************************************

                    nam       Piper
                    ttl       NitrOS-9 Level 1 Null Pipe Driver

                    ifp1
                    use       defsfile
                    use       pipe.d
                    endc

rev                 set       0
edition             set       1

                    mod       eom,name,Drivr+Objct,ReEnt+rev,start,PManMem

                    fcb       UPDAT.

name                fcs       /Piper/
                    fcb       edition

start               lbra      Init
                    lbra      NullIO
                    lbra      NullIO
                    lbra      NullIO
                    lbra      NullIO
                    lbra      Term

Init                clra
                    clrb
                    std       V.List,u
                    andcc     #^Carry
                    rts

NullIO              clrb
                    andcc     #^Carry
                    rts

Term                clrb
                    andcc     #^Carry
                    rts

                    emod
eom                 equ       *
                    end
