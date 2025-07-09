package RAM;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import RegFile::*;
  import TLTypes::*;

  interface RAMIfc;
    interface Put#(TL_AReq) tlIn;
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkRAM(RAMIfc);
    RegFile#(Bit#(10), Bit#(32)) mem <- mkRegFileFull; // 4KB RAM = 1024 x 32-bit words

    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule handleRequest (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      let addr = req.address[11:2];

      if(req.opcode == Get) begin
        let data = mem.sub(addr);
        $display("[RAM] Read from addr %x: %x", req.address, data);
        respFifo.enq(TL_DResp { success: True, data: data });
      end else if (req.opcode == Put) begin
        mem.upd(addr, req.data);
        $display("[RAM] Write to addr %x: %x", req.address, req.data);
        respFifo.enq(TL_DResp { success: True, data: 0 });
      end else begin
        $display("[RAM] Unsupported opcode: %x", req.opcode);
        respFifo.enq(TL_DResp { success: False, data: 0 });
      end
    endrule

    interface Put tlIn = toPut(reqFifo);
    interface Get tlRespOut = toGet(respFifo);
    
  endmodule
endpackage