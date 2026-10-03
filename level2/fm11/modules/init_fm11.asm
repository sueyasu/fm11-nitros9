********************************************************************
* Init - FM-11 NitrOS-9 Level 2 bring-up configuration
*
* Initial Level 2 target deliberately uses /T1 as the console so the
* display subsystem is not part of the first 2D boot milestone.
********************************************************************

                    nam       Init
                    ttl       FM-11 NitrOS-9 Level 2 configuration

                    ifp1
                    use       defsfile
                    endc

rev                 set       $00
edition             set       1
tylg                set       Systm+$00
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,$0FE0,$0015

start               equ       *
                    fcb       $27
                    fdb       DefProg
                    fdb       DefDev
                    fdb       DefCons
                    fdb       DefBoot
                    fcb       $01
                    fcb       Level
                    fcb       NOS9VER
                    fcb       NOS9MAJ
                    fcb       NOS9MIN
                    ifne      H6309
                    fcb       Proc6309+CRCOff
                    else
                    fcb       CRCOff
                    endc
                    fcb       $00
                    fdb       OSStr
                    fdb       InstStr
                    fdb       BuildStr
                    fcb       0,0

* Level 2 configuration tail: MonType, MouseInf, KeyRptS, KeyRptD.
* FM-11 initial serial-console bring-up has no display/mouse subsystem,
* but these five bytes are still part of the Level 2 Init ABI.
                    fcb       0
                    fcb       0,1
                    fcb       $1E
                    fcb       $03

name                fcs       /Init/
                    fcb       edition

DefProg             fcs       /SysGo/
DefDev              fcs       "/DD"
DefCons             fcs       "/T1"
DefBoot             fcs       /Boot/

OSStr               fcc       "NitrOS-9/"
                    ifne      H6309
                    fcc       /6309 /
                    else
                    fcc       /6809 /
                    endc
                    fcc       /Level 2-DEV/
                    fcb       0

InstStr             fcc       /Fujitsu FM-11/
                    fcb       0
BuildStr            fcc       /FM-11 Level 2 8K-pair/
                    fcb       0

                    emod
eom                 equ       *
                    end
