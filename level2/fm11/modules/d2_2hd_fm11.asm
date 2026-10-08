********************************************************************
* D2 - logical /D2 alias for physical /MD0 (2HD boot profile)
********************************************************************

                    nam       D2
                    ttl       FM-11 Level 2 logical /D2 alias for physical /MD0 (2HD boot profile)

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
                    fdb       FM11_MFDC_CMD
                    fcb       initsize-*-1
                    fcb       DT.RBF
                    fcb       0
                    fcb       STP.6ms
                    fcb       TYP.FLP+TYP.SOF+TYP.5+TYP.256
                    fcb       DNS.MFM+DNS.MFM0
                    fdb       40
                    fcb       2
                    fcb       1
                    fdb       16
                    fdb       16
                    fcb       1
                    fcb       1
                    fcb       0
                    fdb       0
                    fcb       0

* 2HD boot profile: /D2 maps to 2D drive 0; cylinder 0 is reserved.
                    fcb       0
                    fcb       0
                    fcb       32
initsize            equ       *
                    fdb       lldrv
                    fcb       $FF

name                fcs       /D2/
mgrnam              fcs       /RBF/
drvnam              fcs       /RBSuper/
lldrv               fcs       /llfm11/

                    emod
eom                 equ       *
                    end
