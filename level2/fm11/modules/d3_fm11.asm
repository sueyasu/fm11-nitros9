********************************************************************
* D3 - logical /D3 alias for physical /ND1
********************************************************************

                    nam       D3
                    ttl       FM-11 Level 2 logical /D3 alias for physical /ND1

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

rev                 set       $00
edition             set       1
tylg                set       Devic+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       DIR.+SHARE.+PREAD.+PWRIT.+PEXEC.+READ.+WRITE.+EXEC.
                    fcb       HW.Page
                    fdb       FM11_FDC_CMD
                    fcb       initsize-*-1
                    fcb       DT.RBF
                    fcb       3
                    fcb       STP.6ms
                    fcb       TYP.FLP+TYP.SOF+TYP.5+TYP.256
                    fcb       DNS.MFM+DNS.DTD
                    fdb       77
                    fcb       2
                    fcb       1
                    fdb       26
                    fdb       26
                    fcb       1
                    fcb       1
                    fcb       0
                    fdb       0
                    fcb       0

* 2D boot profile: /D3 maps to 2HD drive 1; cylinder 0 is reserved.
                    fcb       0
                    fcb       0
                    fcb       52
initsize            equ       *
                    fdb       lldrv
                    fcb       $FF

name                fcs       /D3/
mgrnam              fcs       /RBF/
drvnam              fcs       /RBSuper/
lldrv               fcs       /llfm11/

                    emod
eom                 equ       *
                    end
