package CPUStub;

  import FIFO::*;
  import GetPut::*;
  import TLTypes::*;

  interface CPUStubIfc;
    interface Get#(TL_AReq) reqOut; 
    interface Put#(TL_DResp) respIn;
  endinterface

  module mkCPUStub(CPUStubIfc);

    Reg#(Bool) hasSent <- mkReg(False);
    FIFO#(TL_DResp) dRespFifo <- mkFIFO;
    FIFO#(TL_AReq)  aReqFifo  <- mkFIFO;

    rule sendOnce (!hasSent);
      TL_AReq req = TL_AReq {
        address: 32'h40000000
      };
      aReqFifo.enq(req);
      $display("[CPU] Put to addr %x", req.address);
      hasSent <= True;
    endrule

    interface Get reqOut = toGet(aReqFifo);
    interface Put respIn = toPut(dRespFifo);
  
  endmodule
endpackage