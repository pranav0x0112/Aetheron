package CPUStub;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface CPUStubIfc;
    interface Get#(TL_AReq) reqOut; 
    interface Put#(TL_DResp) respIn;
  endinterface

  module mkCPUStub(CPUStubIfc);

    Reg#(Bit#(32)) pc <- mkReg(0);
    FIFOF#(TL_DResp) dRespFifo <- mkFIFOF;
    FIFOF#(TL_AReq)  aReqFifo  <- mkFIFOF;
    Reg#(Bool) sentReq <- mkReg(False);

    rule sendFetch (!sentReq);
      TL_AReq req = TL_AReq { address: pc };
      aReqFifo.enq(req);
      $display("[CPU] Fetching instruction at addr: %08x", pc);
      sentReq <= True;
    endrule

    rule recvInstr (sentReq && dRespFifo.notEmpty);
      let resp = dRespFifo.first;
      dRespFifo.deq;
      $display("[CPU] Got instruction: %08x", resp.data);
      pc <= pc + 4;
      sentReq <= False;
    endrule

    interface Get reqOut = toGet(aReqFifo);
    interface Put respIn = toPut(dRespFifo);
  
  endmodule
endpackage