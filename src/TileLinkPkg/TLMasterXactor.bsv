package TLMasterXactor;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface TLMasterXactorIfc;
    interface Put#(TL_AReq) reqIn;
    interface Get#(TL_DResp) respOut;
    interface Get#(TL_AReq) tlOut;     
    interface Put#(TL_DResp) tlRespIn;
  endinterface

  module mkTLMasterXactor(TLMasterXactorIfc);
    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule debugFifos;
      if (reqFifo.notEmpty) begin
        $display("[TL Master Debug] Request pending in reqFifo: opcode=%0d, addr=%h", 
                 reqFifo.first.opcode, reqFifo.first.address);
      end
    endrule

    interface Get respOut = toGet(respFifo);
    
    interface Put reqIn;
      method Action put(TL_AReq req);
        $display("[TL Master] Received request: opcode=%0d, addr=%h, data=%h", 
                 req.opcode, req.address, req.data);
        reqFifo.enq(req);
      endmethod
    endinterface

    interface Get tlOut = toGet(reqFifo);

    interface Put tlRespIn;
      method Action put(TL_DResp resp);
        $display("[TL Master] Got response: data=%h", resp.data);
        respFifo.enq(resp);
      endmethod
    endinterface
  endmodule
endpackage