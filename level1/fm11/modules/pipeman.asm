********************************************************************
* PipeMan - NitrOS-9 Level 1 pipe file manager
*
* FM-11 distribution copy.  This implements the standard unnamed
* /Pipe service used by Shell pipelines.  Pipe data is held in a
* 256-byte FIFO allocated from system memory.
*
* A pipe path is deliberately not left under IOMan's PD.CPR lock while
* a Read/Write is active.  Reader and writer share the same path
* descriptor, so retaining that lock while waiting would prevent the
* peer from entering PipeMan.  FIFO pointer/count updates are protected
* by a short IRQ/FIRQ masked critical section instead.
********************************************************************

                    nam       PipeMan
                    ttl       NitrOS-9 Level 1 Pipe File Manager

                    ifp1
                    use       defsfile
                    use       pipe.d
                    endc

PipeSize            equ       256

rev                 set       0
edition             set       3
tylg                set       FlMgr+Objct
atrv                set       ReEnt+rev

                    mod       eom,name,tylg,atrv,start,0

name                fcs       /PipeMan/
                    fcb       edition

********************************************************************
* File manager branch table
* Entry: Y = path descriptor, U = caller register stack
********************************************************************
start               lbra      Create
                    lbra      Open
                    lbra      BadService          MakDir
                    lbra      BadService          ChgDir
                    lbra      BadService          Delete
                    lbra      BadService          Seek
                    lbra      PRead
                    lbra      PWrite
                    lbra      PRdLn
                    lbra      PWrLn
                    lbra      GetStat
                    lbra      SetStat
                    lbra      Close

********************************************************************
* Create/Open
*
* Unnamed /Pipe paths use one shared path descriptor.  IOMan handles
* Dup/Fork reference counting in PD.CNT.
********************************************************************
Create              equ       *
Open                ldd       #PipeSize
                    os9       F$SRqMem
                    bcs       OpenExit

                    stu       PD.BUF,y
                    stu       PD.NxtI,y
                    stu       PD.NxtO,y
                    leax      PipeSize,u
                    stx       PD.End,y
                    ldd       #PipeSize
                    std       PD.QSiz,y
                    clra
                    clrb
                    std       PD.BCnt,y
                    clr       PD.RCT,y
                    clr       PD.WCT,y
                    clr       PD.RPID,y
                    clr       PD.WPID,y
                    clr       PD.RSIG,y
                    clr       PD.WSIG,y
                    clr       PD.RFlg,y
                    clr       PD.Wrtn,y
                    clr       PD.Keep,y
                    ldx       <D.Proc
                    lda       P$ID,x
                    sta       PD.Own,y

                    clrb
                    andcc     #^Carry
OpenExit            rts

********************************************************************
* ReleaseIOBlock
*
* IOMan sets PD.CPR before entering a file manager.  A pipe must permit
* the peer process to enter the same path while this process is waiting.
* Mask interrupts so no process can observe the path between entry and
* releasing the lock.
********************************************************************
ReleaseIOBlock      pshs      cc
                    orcc      #IntMasks
                    clr       PD.CPR,y
                    puls      cc,pc

********************************************************************
* PRead / PRdLn
*
* Read returns immediately with any bytes currently available.  If the
* FIFO is empty before the first byte, yield until a writer supplies data.
* Once this is the only remaining user of an empty unnamed pipe, EOF is
* returned.  ReadLn additionally stops after C$CR.
********************************************************************
PRead               clra                          raw read
                    bra       ReadCommon
PRdLn               lda       #1                  line read

ReadCommon          pshs      u                   save our caller register stack
                    pshs      y                   save this pipe path descriptor
                    pshs      a                   line-mode flag
                    ldd       R$Y,u
                    pshs      d                   bytes remaining
                    ldx       R$X,u               destination pointer
                    lbsr      ReleaseIOBlock
                    ldd       ,s
                    beq       ReadSuccess

ReadLoop            ldd       ,s
                    beq       ReadSuccess

* Protect FIFO state from task switches while one element is removed.
                    pshs      cc
                    orcc      #IntMasks
                    ldd       PD.BCnt,y
                    beq       ReadEmpty
                    subd      #1
                    std       PD.BCnt,y
                    ldu       PD.NxtO,y
                    lda       ,u+
                    cmpu      PD.End,y
                    blo       ReadPtrOK
                    ldu       PD.BUF,y
ReadPtrOK           stu       PD.NxtO,y
                    puls      cc

                    sta       ,x+
                    tst       2,s                 ReadLn?
                    beq       ReadMore
                    cmpa      #C$CR
                    beq       ReadLineDone
ReadMore            ldd       ,s
                    subd      #1
                    std       ,s
                    bra       ReadLoop
ReadLineDone        ldd       ,s
                    subd      #1
                    std       ,s
                    bra       ReadSuccess

ReadEmpty           puls      cc
                    ldu       5,s                 our saved caller register stack
                    cmpx      R$X,u               already transferred something?
                    beq       ReadEmptyNone

* Raw Read may return the bytes already available.  ReadLn must not return a
* partial line merely because the producer temporarily drained the FIFO; keep
* waiting for C$CR while a writer still owns the pipe.
                    tst       2,s                 ReadLn?
                    beq       ReadSuccess          raw read: partial result is valid
                    lda       PD.CNT,y
                    cmpa      #1                  writer has closed?
                    bls       ReadSuccess          yes: return final unterminated line
                    bra       ReadWait

ReadEmptyNone       lda       PD.CNT,y
                    cmpa      #1                  no writer remains?
                    bls       ReadEOF

* No complete line/data yet.  Give the rest of this time slice to the writer.
* Preserve both the partial destination pointer and our path descriptor: the
* peer may enter PipeMan on this same path while we sleep.
ReadWait            pshs      x,y
                    ldx       #1
                    os9       F$Sleep
                    puls      x,y
                    bcs       ReadError
                    bra       ReadLoop

ReadSuccess         ldu       5,s                 our saved caller register stack
                    ldd       R$Y,u               requested count
                    subd      ,s                   minus remaining
                    std       R$Y,u               = actual count
                    leas      7,s
                    clrb
                    andcc     #^Carry
                    rts

ReadEOF             leas      7,s
                    ldb       #E$EOF
                    orcc      #Carry
                    rts

ReadError           leas      7,s
                    orcc      #Carry
                    rts

********************************************************************
* PWrite / PWrLn
*
* Write blocks by yielding when the FIFO is full.  If the writer is the
* only remaining user and the FIFO is full, no reader can make progress,
* so return E$Write.  WritLn stops after C$CR.
********************************************************************
PWrite              clra                          raw write
                    bra       WriteCommon
PWrLn               lda       #1                  line write

WriteCommon         pshs      u                   save our caller register stack
                    pshs      y                   save this pipe path descriptor
                    pshs      a                   line-mode flag
                    ldd       R$Y,u
                    pshs      d                   bytes remaining
                    ldx       R$X,u               source pointer
                    lbsr      ReleaseIOBlock
                    ldd       ,s
                    beq       WriteSuccess

WriteLoop           ldd       ,s
                    beq       WriteSuccess

                    pshs      cc
                    orcc      #IntMasks
                    ldd       PD.BCnt,y
                    cmpd      PD.QSiz,y
                    bhs       WriteFull
                    addd      #1
                    std       PD.BCnt,y
                    ldu       PD.NxtI,y
                    lda       ,x                   candidate byte
                    sta       ,u+
                    cmpu      PD.End,y
                    blo       WritePtrOK
                    ldu       PD.BUF,y
WritePtrOK          stu       PD.NxtI,y
                    puls      cc

                    leax      1,x
                    inc       PD.Wrtn,y
                    tst       2,s                 WritLn?
                    beq       WriteMore
                    cmpa      #C$CR
                    beq       WriteLineDone
WriteMore           ldd       ,s
                    subd      #1
                    std       ,s
                    bra       WriteLoop
WriteLineDone       ldd       ,s
                    subd      #1
                    std       ,s
                    bra       WriteSuccess

WriteFull           puls      cc
                    lda       PD.CNT,y
                    cmpa      #1
                    bls       WriteBroken

* FIFO is full but a reader still exists.  Yield and retry the same byte.
* Preserve X and Y explicitly; PD.RGS may point at the peer after it runs.
                    pshs      x,y
                    ldx       #1
                    os9       F$Sleep
                    puls      x,y
                    bcs       WriteError
                    bra       WriteLoop

WriteSuccess        ldu       5,s                 our saved caller register stack
                    ldd       R$Y,u
                    subd      ,s
                    std       R$Y,u
                    leas      7,s
                    clrb
                    andcc     #^Carry
                    rts

WriteBroken         leas      7,s
                    ldb       #E$Write
                    orcc      #Carry
                    rts

WriteError          leas      7,s
                    orcc      #Carry
                    rts

********************************************************************
* GetStat / SetStat
*
* The basic pipe path deliberately treats status requests as no-ops.  This
* matches the useful compatibility behaviour for ordinary Shell pipelines.
********************************************************************
GetStat             clrb
                    andcc     #^Carry
                    rts

SetStat             lbra      BadService

********************************************************************
* Close
*
* IOMan has already decremented PD.CNT before calling us.  Return the FIFO
* only after the last image of this unnamed pipe is closed.
********************************************************************
Close               tst       PD.CNT,y
                    bne       CloseOK
                    ldu       PD.BUF,y
                    beq       CloseOK
                    ldd       #PipeSize
                    os9       F$SRtMem
                    bcs       CloseExit
                    clra
                    clrb
                    std       PD.BUF,y
CloseOK             clrb
                    andcc     #^Carry
CloseExit           rts

BadService          ldb       #E$UnkSvc
                    orcc      #Carry
                    rts

                    emod
eom                 equ       *
                    end
