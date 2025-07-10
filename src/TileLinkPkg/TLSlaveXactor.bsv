package TLSlaveXactor;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface TLSlaveXactorIfc;
    interface Put#(TL_AReq) tlIn;           // From TL master
    interface Get#(TL_DResp) respOut;       // Back To TL master
    interface Get#(TL_AReq) periphOut;     
    interface Get#(TL_AReq) romOut;         
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

    rule debugFifos;
      if (reqFifo.notEmpty) begin
        $display("[TL Slave Debug] Request pending in reqFifo: opcode=%0d, addr=%h", 
                 reqFifo.first.opcode, reqFifo.first.address);
      end
    endrule

    rule routeToPeriph if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      Bool routed = False;

      if (req.address >= 32'h00000000 && req.address < 32'h00010000) begin
        romFifo.enq(req);
        $display("[TL Slave] Routed to ROM: addr=%h", req.address);
        routed = True;
      end else if (req.address >= 32'h40000000 && req.address < 32'h40010000) begin
        periphFifo.enq(req);
        $display("[TL Slave] Routed to GPIO: addr=%h", req.address);
        routed = True;
      end else if (req.address >= 32'h80000000 && req.address < 32'h80001000) begin
        ramFifo.enq(req);
        $display("[TL Slave] Routed to RAM: addr=%h", req.address);
        routed = True;
      end else begin
        $display("[TL Slave] Unknown address: %h - sending default response", req.address);
        respFifo.enq(TL_DResp{success: False, data: 32'hDEADBEEF});
      end
    endrule
    
    rule forwardROMResp (romRespFifo.notEmpty);
      let resp = romRespFifo.first;
      romRespFifo.deq;

      $display("[TL Slave] Forwarding ROM response: %h", resp.data);
      respFifo.enq(resp);
    endrule

    rule forwardRAMResp (ramRespFifo.notEmpty);
      let resp = ramRespFifo.first;
      ramRespFifo.deq;

      $display("[TL Slave] Forwarding RAM response: %h", resp.data);
      respFifo.enq(resp);
    endrule

    interface Put tlIn;
      method Action put(TL_AReq req);
        $display("[TL Slave] Received A-channel request: opcode=%0d, addr=%h, data=%h", 
                 req.opcode, req.address, req.data);
        reqFifo.enq(req);
      endmethod
    endinterface

    interface Get respOut = toGet(respFifo);
    interface Get periphOut = toGet(periphFifo);
    interface Get romOut = toGet(romFifo);    
    interface Put romIn = toPut(romRespFifo);
    interface Get ramOut = toGet(ramFifo);    
    interface Put ramIn = toPut(ramRespFifo);
  endmodule
endpackage