********************************************************************
* D3 - FM-11 logical /D3 alias for physical /MD1 (2HD boot profile)
********************************************************************

                    nam       D3
                    ttl       FM-11 logical /D3 alias for physical /MD1 (2HD boot profile)

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

rev                 set       $00
tylg                set       Devic+Objct
atrv                set       ReEnt+rev
edition             set       3

* Physical-device name used by the Fujitsu FM-11 OS-9 naming convention.
* /D1 is a separate logical descriptor pointing at the same physical drive.

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       DIR.+SHARE.+PREAD.+PWRIT.+PEXEC.+READ.+WRITE.+EXEC.
                    fcb       HW.Page
                    fdb       FM11_MFDC_CMD
                    fcb       initsize-*-1
                    fcb       DT.RBF
                    fcb       1                   drive number
                    fcb       STP.6ms
                    fcb       TYP.FLP+TYP.SOF+TYP.5+TYP.256
                    fcb       DNS.MFM+DNS.MFM0      MFM; track 0 is also MFM
                    fdb       40                  cylinders
                    fcb       2                   sides
                    fcb       1                   write verify disabled for now
                    fdb       16                  sectors/track
                    fdb       16                  track 0 sectors
                    fcb       1                   interleave
                    fcb       1                   segment allocation size
                    fcb       0                   IT.TFM
                    fdb       0                   IT.Exten
                    fcb       0                   IT.SToff

* RBSuper-only descriptor extension.  The complete first physical track (32 sectors) is reserved for the
* FM-11 ROM IPL and NitrOS-9 boottrack.  RBF logical LSN0 therefore
* starts at physical sector 32 (T1/H0/S1).
                    fcb       0                   IT.SOFF1
                    fcb       0                   IT.SOFF2
                    fcb       32                  IT.SOFF3
initsize            equ       *
                    fdb       lldrv               IT.LLDRV
                    fcb       $FF                 IT.MPI (unused on FM-11)

name                fcs       /D3/
mgrnam              fcs       /RBF/
drvnam              fcs       /RBSuper/
lldrv               fcs       /llfm11/

                    emod
eom                 equ       *
                    end
