********************************************************************
* fm11serial - Fujitsu FM-11 USART0 SCF Driver
*
* Level 1 polling driver for the FM-11 USART at FD06/FD07.
*
* v20 yields the current process time slice while waiting for RXRDY/TXRDY
* so a blocked serial terminal cannot starve another runnable process.
* Interrupt-driven serial I/O can replace this later.
********************************************************************

                    nam       fm11serial
                    ttl       Fujitsu FM-11 USART0 SCF Driver

                    ifp1
                    use       defsfile
                    endc

* FM-11 USART register offsets relative to V.PORT (= UART_DATA)
                    org       0
DataReg             rmb       1
CtrlReg             rmb       1
StatReg             equ       CtrlReg

* Status bits verified with fm11-headless
StatTxRdy           equ       $01
StatRxRdy           equ       $02

* 8251 initialization values verified with fm11-headless
Mode8N1x16          equ       $4E
CmdEnable           equ       $37

* No driver-private storage is needed yet.  V.SCF is the size of the
* storage maintained by SCF itself.
                    org       V.SCF
MemSize             equ       .

rev                 set       0
edition             set       2

                    mod       ModSize,ModName,Drivr+Objct,ReEnt+rev,ModEntry,MemSize

                    fcb       UPDAT.

ModName             fcs       /fm11serial/
                    fcb       edition

********************************************************************
* Driver jump table
********************************************************************

ModEntry            lbra      Init
                    lbra      Read
                    lbra      Write
                    lbra      GStt
                    lbra      SStt
                    lbra      Term

********************************************************************
* Init
*
* Y = device descriptor
* U = device static storage
********************************************************************

Init                pshs      dp
                    tfr       u,d
                    tfr       a,dp

                    ldx       <V.PORT

* USART0 is already initialized by FM-11 REL.
* Do not issue a second 8251 mode/command sequence here.

                    clrb
                    andcc     #^Carry
                    puls      dp,pc

********************************************************************
* Term
********************************************************************

Term                clrb
                    andcc     #^Carry
                    rts

********************************************************************
* Read
*
* Returns character in A.  Poll RXRDY, but yield the remainder of the
* current time slice when no character is ready.  X=1 is the Level 1
* F$Sleep convention for giving other runnable processes a chance to run.
********************************************************************

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

********************************************************************
* Write
*
* Input character is in A.  Poll TXRDY, yielding the remainder of the
* current time slice while the transmitter is not ready.
********************************************************************

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

********************************************************************
* GetStat
*
* Minimal SCF services needed for bring-up:
*   SS.EOF   - serial devices never report EOF
*   SS.Ready - report one character when RXRDY is set
*   SS.ScSiz - report 80x25 terminal size
********************************************************************

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

********************************************************************
* SetStat
*
* For initial bring-up the UART configuration is fixed at 9600 8N1 by
* the host-side PTY/emulator.  Accept the common SCF control calls as
* no-ops.  Unsupported calls return E$UnkSvc.
********************************************************************

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
