package TLSlaveXactor;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface TLSlaveXactorIfc;
    interface Put#(TL_AReq) tlIn;           // From TL master
    interface Get#(TL_DResp) respOut;       // Back To TL master
    interface Put#(TL_AReq) periphOut;      // To GPIO
    interface Put#(TL_AReq) romOut;
    interface Put#(TL_DResp) romIn;
    interface Get#(TL_AReq) ramOut;
    interface Put#(TL_DResp) ramIn;
  endinterface

  module mkTLSlaveXactor(TLSlaveXactorIfc);
    
    FIFOF#(TL_AReq)  reqFifo    <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo   <- mkFIFOF;
    FIFOF#(TL_AReq)  periphFifo <- mkFIFOF;
    FIFOF#(TL_AReq)  romFifo    <- mkFIFOF;
    FIFOF#(TL_DResp) romRespFifo <- mkFIFOF;
    FIFOF#(TL_AReq)  ramFifo    <- mkFIFOF;
    FIFOF#(TL_DResp) ramRespFifo <- mkFIFOF;

    rule routeToPeriph if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      Bool routed = False;

      if (req.address >= 32'h00000000 && req.address < 32'h00010000) begin
        romFifo.enq(req);
        $display("[TL Slave] Routed to ROM");
        routed = True;
      end else if (req.address >= 32'h40000000 && req.address < 32'h40010000) begin
        periphFifo.enq(req);
        $display("[TL Slave] Routed to GPIO");
        routed = True;
      end else if (req.address >= 32'h80000000 && req.address < 32'h80001000) begin
        ramFifo.enq(req);
        $display("[TL Slave] Routed to RAM");
        routed = True;
      end else begin
        $display("[TL Slave] Unknown address: %x", req.address);
      end
    endrule
    
    rule forwardROMResp (romRespFifo.notEmpty);
      let resp = romRespFifo.first;
      romRespFifo.deq;

      $display("[TL Slave] Forwarding ROM response: %x", resp.data);
      respFifo.enq(resp);
    endrule

    rule forwardRAMResp (ramRespFifo.notEmpty);
      let resp = ramRespFifo.first;
      ramRespFifo.deq;

      $display("[TL Slave] Forwarding RAM response: %x", resp.data);
      respFifo.enq(resp);
    endrule

    interface Put tlIn;
      method Action put(TL_AReq req);
        $display("[TL Slave] Received A-channel request: opcode=%0d, addr=%x, data=%x", req.opcode, req.address, req.data);
        reqFifo.enq(req);
      endmethod
    endinterface

    interface Get respOut  = toGet(respFifo);
    interface Put periphOut  = toPut(periphFifo);
    interface Put romOut = toPut(romFifo);
    interface Put romIn = toPut(romRespFifo);
    interface Get ramOut = toGet(ramFifo);
    interface Put ramIn  = toPut(ramRespFifo);

  endmodule

endpackage