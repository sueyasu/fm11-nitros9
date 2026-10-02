********************************************************************
* FM11Trmp - install the FM-11 Level 2 fixed-RAM trampoline
********************************************************************

                    nam       FM11Trmp
                    ttl       FM-11 Level 2 fixed trampoline installer

                    IFP1
                    use       defsfile
                    ENDC

tylg                set       Systm+Objct
atrv                set       ReEnt+rev
rev                 set       0
edition             set       1

                    mod       eom,name,tylg,atrv,Start,0

name                fcs       /FM11Trmp/
                    fcb       edition

TrampPayload
FM11_TRAMP_EMBED    set       1
                    use       fm11tramp.asm
FM11_TRAMP_EMBED    set       0
TrampPayloadEnd

Start
                    pshs      cc,d,x,y,u
                    orcc      #IntMasks

                    leax      >TrampPayload,pcr
                    ldy       #FM11_L2_TRAMP
                    ldu       #TrampPayloadEnd-TrampPayload
CopyTramp           lda       ,x+
                    sta       ,y+
                    leau      -1,u
                    cmpu      #0
                    bne       CopyTramp

                    ldd       #FM11_L2_SWI3
                    std       >$FFF2
                    ldd       #FM11_L2_SWI2
                    std       >$FFF4
                    ldd       #FM11_L2_FIRQ
                    std       >$FFF6
                    ldd       #FM11_L2_IRQ
                    std       >$FFF8
                    ldd       #FM11_L2_SWI
                    std       >$FFFA
                    ldd       #FM11_L2_NMI
                    std       >$FFFC

                    puls      cc,d,x,y,u,pc

                    emod
eom                 equ       *
                    end
