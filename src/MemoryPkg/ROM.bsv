package ROM;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import RegFile::*;
  import TLTypes::*;

  interface ROMIfc;
    interface Put#(TL_AReq) tlIn;  
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkROM(ROMIfc);
    RegFile#(Bit#(10), Bit#(32)) mem <- mkRegFileLoad("hex/rom.hex", 0, 1023);

    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule debugROM;
      if (reqFifo.notEmpty) begin
        $display("[ROM Debug] Request pending: addr=%h", reqFifo.first.address);
      end
    endrule

    rule handleRead (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      let addr = req.address[11:2];
      let data = mem.sub(addr);

      $display("[ROM] Read from addr %x: %x", req.address, data);

      respFifo.enq(TL_DResp { success: True, data: data });
    endrule

    interface Put tlIn = toPut(reqFifo);  
    interface Get tlRespOut = toGet(respFifo);
  endmodule
endpackage