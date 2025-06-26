package TLSlaveXactor;

  import TileLink::TLTypes::*;

  interface TLSlaveXactorIfc;
    interface Put#(TL_AReq) tlIn; // From TileLink Bus
    interface Get#(TL_DResp) tlRespOut; // To TileLink Master
    interface Put#(TL_AReq) periphOut; // To GPIO
  endinterface

  module mkTLSlaveXactor(TLSlaveXactorIfc);

    FIFO#(TL_AReq) reqFifo <- mkFIFO;
    FIFO#(TL_DResp) respFifo <- mkFIFO;
    FIFO#(TL_AReq)  periphFifo <- mkFIFO;

   interface Put tlIn;
      method Bool canPut = inFifo.notFull;
      method Action put(TL_AReq req);
        $display("[TL Slave] Received A-channel PutFullData to addr=%x", req.address);
        reqFifo.enq(req);
      endmethod
    endinterface

    rule routeToPeriph if (inFifo.notEmpty);
      let req = inFifo.first;

      if (req.address >= 32'h40000000 && req.address < 32'h4000FFFF)
        begin
          periphFifo.enq(req);
          $display("[TL Slave] Routed to GPIO");
        end else
        begin
          $display("[TL Slave] Unknown address: %x", req.address);
        end

      inFifo.deq();
      respFifo.enq(TL_DResp{ success: True });
    endrule

    interface Get tlRespOut = toGet(respFifo);
    interface Put periphOut = toPut(periphFifo);

  endmodule
endpackage