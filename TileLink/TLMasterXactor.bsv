package TLMasterXactor;

  import TileLink::TLTypes::*;

  interface TLMasterXactorIfc;
    interface Put#(TL_AReq) reqIn;
    interface Get#(TL_DResp) respOut;

    interface Put#(TL_AReq) tlOut;
    interface Get#(TL_DResp) tlRespIn;
  
  endinterface

  module mkTLMasterXactor(TLMasterXactorIfc);

    FIFO#(TL_AReq) reqFifo <- mkFIFO;
    FIFO#(TL_DResp) respFifo <- mkFIFO;

    Reg#(Bool) sent <- mkReg(False);

    interface Get respOut = toGet(respFifo);  // Connects TileLink responses back to CPU(Master)
    
    // Accept req from CPU(Master) 
    interface Put reqIn;
      method Bool canPut = reqFifo.notFull;
      method Action put(TL_AReq req);
        reqFifo.enq(req);
      endmethod
    endinterface

    // Drive outgoing TileLink requests
    interface Put tlOut;
      method Bool canPut = !sent && reqFifo.notEmpty;
      method Action put(TL_AReq req);
        let r <- reqFifo.first;
        $display("[TL Master] Sending PutFullData: addr=%x, data=%x", r.address, r.data);
        reqFifo.deq();
        sent <= True;
      endmethod
    endinterface

    // Accept TileLink responses 

    interface Get tlRespIn;
      method ActionValue#(TL_DResp) get;
        let resp = TL_DResp{ success: True };
        $display("[TL Master] Got AccessAck");
        respFifo.enq(resp);
        return resp;
      endmethod
    endinterface

  endmodule
endpackage