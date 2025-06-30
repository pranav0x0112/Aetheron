package TLSlaveXactor;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface TLSlaveXactorIfc;
    interface Put#(TL_AReq) tlIn;           // From TL master
    interface Get#(TL_DResp) respOut;       // Bac To TL master
    interface Put#(TL_AReq) periphOut;      //  To GPIO
  endinterface

  module mkTLSlaveXactor(TLSlaveXactorIfc);
    
    FIFOF#(TL_AReq)  reqFifo    <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo   <- mkFIFOF;
    FIFOF#(TL_AReq)  periphFifo <- mkFIFOF;

    rule routeToPeriph if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      if (req.address >= 32'h40000000 && req.address < 32'h4000FFFF) begin
        periphFifo.enq(req);
        $display("[TL Slave] Routed to GPIO");
      end else begin
        $display("[TL Slave] Unknown address: %x", req.address);
      end

      respFifo.enq(TL_DResp{ success: True });
    endrule

    interface Put tlIn;
      method Action put(TL_AReq req);
        $display("[TL Slave] Received A-channel PutFullData to addr=%x", req.address);
        reqFifo.enq(req);
      endmethod
    endinterface

    interface Get respOut  = toGet(respFifo);
    interface Put periphOut  = toPut(periphFifo);
  endmodule
endpackage