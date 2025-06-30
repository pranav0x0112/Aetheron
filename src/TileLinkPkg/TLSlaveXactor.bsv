package TLSlaveXactor;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface TLSlaveXactorIfc;
    interface Put#(TL_AReq) tlIn;           // From TL master
    interface Get#(TL_DResp) respOut;       // Bac To TL master
    interface Put#(TL_AReq) periphOut;      //  To GPIO
    interface Put#(TL_AReq) romOut;
    interface Put#(TL_DResp) romIn;
  endinterface

  module mkTLSlaveXactor(TLSlaveXactorIfc);
    
    FIFOF#(TL_AReq)  reqFifo    <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo   <- mkFIFOF;
    FIFOF#(TL_AReq)  periphFifo <- mkFIFOF;
    FIFOF#(TL_AReq)  romFifo    <- mkFIFOF;
    FIFOF#(TL_DResp) romRespFifo <- mkFIFOF;

    rule routeToPeriph if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      if (req.address >= 32'h00000000 && req.address < 32'h0000FFFF) begin
        romFifo.enq(req);
        $display("[TL Slave] Routed to ROM");
      end else if (req.address >= 32'h40000000 && req.address < 32'h4000FFFF) begin
        periphFifo.enq(req);
        $display("[TL Slave] Routed to GPIO");
      end else begin
        $display("[TL Slave] Unknown address: %x", req.address);
      end

      respFifo.enq(TL_DResp{ success: True });
    endrule

    rule forwardROMResp (romRespFifo.notEmpty);
      let resp = romRespFifo.first;
      romRespFifo.deq;

      $display("[TL Slave] Forwarding ROM response: %x", resp.data);
      respFifo.enq(resp);
    endrule

    interface Put tlIn;
      method Action put(TL_AReq req);
        $display("[TL Slave] Received A-channel PutFullData to addr=%x", req.address);
        reqFifo.enq(req);
      endmethod
    endinterface

    interface Get respOut  = toGet(respFifo);
    interface Put periphOut  = toPut(periphFifo);
    interface Put romOut = toPut(romFifo);
    interface Put romIn = toPut(romRespFifo);
  endmodule
endpackage