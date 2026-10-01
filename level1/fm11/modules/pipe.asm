********************************************************************
* Pipe - NitrOS-9 Level 1 pipe device descriptor
********************************************************************

                    nam       Pipe
                    ttl       NitrOS-9 Level 1 Pipe Device Descriptor

                    ifp1
                    use       defsfile
                    use       pipe.d
                    endc

rev                 set       0
tylg                set       Devic+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       UPDAT.              mode
                    fcb       $00                 no extended port page
                    fdb       $0000               no physical controller
                    fcb       initsize-*-1
                    fcb       DT.Pipe             pipe device class
                    fcb       1                   one byte per queue element
                    fdb       256                 256 queue elements
initsize            equ       *

name                fcs       /Pipe/
mgrnam              fcs       /PipeMan/
drvnam              fcs       /Piper/

                    emod
eom                 equ       *
                    end
