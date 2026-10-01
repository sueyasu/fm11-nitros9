********************************************************************
* DD - FM-11 MDC boot hard disk, Fujitsu M2243B profile
********************************************************************

                    nam       DD
                    ttl       FM-11 /DD M2243B hard disk descriptor

                    ifp1
                    use       defsfile
                    use       rbsuper.d
                    endc

rev                 set       $00
tylg                set       Devic+Objct
atrv                set       ReEnt+rev
edition             set       1

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       DIR.+SHARE.+PREAD.+PWRIT.+PEXEC.+READ.+WRITE.+EXEC.
                    fcb       HW.Page
                    fdb       FM11_MDC_CMD
                    fcb       initsize-*-1
                    fcb       DT.RBF
                    fcb       4                   RBSuper drive-table slot; llfm11hd maps 4 -> MDC drive 0
                    fcb       STP.6ms             unused by MDC
                    fcb       TYP.HARD+TYP.SOF+TYP.256
                    fcb       0                   density flags unused for HDD
                    fdb       747                 M2243B cylinders
                    fcb       11                  heads
                    fcb       1                   write verify disabled
                    fdb       32                  256-byte records/track
                    fdb       32                  track 0 records
                    fcb       1                   interleave
                    fcb       8                   allocation cluster hint
                    fcb       0                   IT.TFM
                    fdb       0                   IT.Exten
                    fcb       0                   IT.SToff
                    fcb       0                   IT.SOFF1
                    fcb       0                   IT.SOFF2
                    fcb       19                  IT.SOFF3; sectors 0-18 reserved for IPL/Bootp1
initsize            equ       *
                    fdb       lldrv               IT.LLDRV
                    fcb       $FF                 IT.MPI

name                fcs       /DD/
mgrnam              fcs       /RBF/
drvnam              fcs       /RBSuper/
lldrv               fcs       /llfm11hd/

                    emod
eom                 equ       *
                    end
