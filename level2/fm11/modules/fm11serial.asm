********************************************************************
* fm11serial - FM-11 Level 2 USART0 polling SCF driver
********************************************************************

                    nam       fm11serial
                    ttl       FM-11 Level 2 USART0 SCF driver

                    ifp1
                    use       defsfile
                    endc

                    org       0
DataReg             rmb       1
CtrlReg             rmb       1
StatReg             equ       CtrlReg

StatTxRdy           equ       $01
StatRxRdy           equ       $02

                    org       V.SCF
MemSize             equ       .

rev                 set       0
edition             set       1

                    mod       ModSize,ModName,Drivr+Objct,ReEnt+rev,ModEntry,MemSize
                    fcb       UPDAT.

ModName             fcs       /fm11serial/
                    fcb       edition

ModEntry            lbra      Init
                    lbra      Read
                    lbra      Write
                    lbra      GStt
                    lbra      SStt
                    lbra      Term

Init                clrb
                    andcc     #^Carry
                    rts

Term                clrb
                    andcc     #^Carry
                    rts

Read                pshs      dp
                    tfr       u,d
                    tfr       a,dp
                    ldx       <V.PORT
ReadWait            lda       StatReg,x
                    bita      #StatRxRdy
                    bne       ReadReady
                    ldx       #1
                    os9       F$Sleep
                    ldx       <V.PORT
                    bra       ReadWait
ReadReady           lda       DataReg,x
                    clrb
                    andcc     #^Carry
                    puls      dp,pc

Write               pshs      dp
                    pshs      a
                    tfr       u,d
                    tfr       a,dp
                    puls      a
                    ldx       <V.PORT
WriteWait           ldb       StatReg,x
                    bitb      #StatTxRdy
                    bne       WriteReady
                    pshs      a
                    ldx       #1
                    os9       F$Sleep
                    puls      a
                    ldx       <V.PORT
                    bra       WriteWait
WriteReady          sta       DataReg,x
                    clrb
                    andcc     #^Carry
                    puls      dp,pc

GStt                pshs      dp
                    pshs      a
                    tfr       u,d
                    tfr       a,dp
                    puls      a
                    cmpa      #SS.EOF
                    beq       GSOk
                    cmpa      #SS.Ready
                    beq       GSReady
                    cmpa      #SS.ScSiz
                    beq       GSScSiz
                    ldb       #E$UnkSvc
                    orcc      #Carry
                    puls      dp,pc

GSReady             ldx       <V.PORT
                    ldb       StatReg,x
                    bitb      #StatRxRdy
                    beq       GSNotReady
                    ldx       PD.RGS,y
                    ldb       #1
                    stb       R$B,x
                    bra       GSOk
GSNotReady          ldb       #E$NotRdy
                    orcc      #Carry
                    puls      dp,pc

GSScSiz             ldx       PD.RGS,y
                    ldd       #80
                    std       R$X,x
                    ldd       #25
                    std       R$Y,x
GSOk                clrb
                    andcc     #^Carry
                    puls      dp,pc

SStt                cmpa      #SS.Open
                    beq       SSOk
                    cmpa      #SS.Close
                    beq       SSOk
                    cmpa      #SS.ComSt
                    beq       SSOk
                    cmpa      #SS.HngUp
                    beq       SSOk
                    cmpa      #SS.Break
                    beq       SSOk
                    ldb       #E$UnkSvc
                    orcc      #Carry
                    rts
SSOk                clrb
                    andcc     #^Carry
                    rts

                    emod
ModSize             equ       *
                    end
