package TLMasterXactor;

  import FIFO::*;
  import GetPut::*;
  import TLTypes::*;

  interface TLMasterXactorIfc;
    interface Put#(TL_AReq) reqIn;
    interface Get#(TL_DResp) respOut;
    interface Get#(TL_AReq) tlOut;     
    interface Put#(TL_DResp) tlRespIn;
  endinterface


  module mkTLMasterXactor(TLMasterXactorIfc);

    FIFO#(TL_AReq) reqFifo <- mkFIFO;
    FIFO#(TL_DResp) respFifo <- mkFIFO;
    FIFO#(TL_AReq) outFifo <- mkFIFO;  // New FIFO for outgoing requests

    Reg#(Bool) sent <- mkReg(False);
    Reg#(Bool) hasReq <- mkReg(False);
    Reg#(TL_AReq) currentReq <- mkRegU;

    // Rule to extract a request from the FIFO
    rule extractReq (!hasReq && !sent);
      let req = reqFifo.first;
      reqFifo.deq;
      currentReq <= req;
      hasReq <= True;
    endrule

    // Rule to forward request to outFifo
    rule forwardReq (hasReq && !sent);
      $display("[TL Master] Sending PutFullData: addr=%x", currentReq.address);
      outFifo.enq(currentReq);
      hasReq <= False;
      sent <= True;
    endrule

    interface Get respOut = toGet(respFifo);
    
    interface Put reqIn;
      method Action put(TL_AReq req);
        reqFifo.enq(req);
      endmethod
    endinterface

    interface Get tlOut = toGet(outFifo);

    interface Put tlRespIn;
      method Action put(TL_DResp resp);
        $display("[TL Master] Got AccessAck");
        respFifo.enq(resp);
      endmethod
    endinterface

  endmodule
endpackage