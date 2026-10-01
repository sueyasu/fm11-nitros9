********************************************************************
* DD - FM-11 system disk alias for /ND0 (2HD boot profile)
********************************************************************

                    nam       DD
                    ttl       FM-11 /DD system disk alias for physical /ND0 (2HD boot profile)

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

rev                 set       $00
tylg                set       Devic+Objct
atrv                set       ReEnt+rev
edition             set       4

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       DIR.+SHARE.+PREAD.+PWRIT.+PEXEC.+READ.+WRITE.+EXEC.
                    fcb       HW.Page
                    fdb       FM11_FDC_CMD
                    fcb       initsize-*-1
                    fcb       DT.RBF
                    fcb       2                 RBSuper drive-table slot
                    fcb       STP.6ms
                    fcb       TYP.FLP+TYP.SOF+TYP.5+TYP.256
                    fcb       DNS.MFM+DNS.DTD  96 TPI MFM; T0/H0 is native FM 128-byte
                    fdb       77                   cylinders
                    fcb       2                    sides
                    fcb       1                    write verify disabled
                    fdb       26                   sectors/track
                    fdb       26                   track 0 sectors
                    fcb       1                    interleave
                    fcb       1                    segment allocation size
                    fcb       0                    IT.TFM
                    fdb       0                    IT.Exten
                    fcb       0                    IT.SToff

* FM-series OS-9 hides the complete boot cylinder from RBF.  Treat it as
* 52 abstract 256-byte sectors so physical sector 52 maps to T1/H0/S1.
* Physical cylinder 0 is reserved for the FM-11 IPL/boottrack.
* Native 2HD geometry uses T0/H0=26x128-byte FM and T0/H1=26x256-byte MFM.
                    fcb       0                    IT.SOFF1
                    fcb       0                    IT.SOFF2
                    fcb       52                   IT.SOFF3
initsize            equ       *
                    fdb       lldrv                IT.LLDRV
                    fcb       $FF                 IT.MPI (unused on FM-11)

name                fcs       /DD/
mgrnam              fcs       /RBF/
drvnam              fcs       /RBSuper/
lldrv               fcs       /llfm11/

                    emod
eom                 equ       *
                    end
