package ROM;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import RegFile::*;
  import TLTypes::*;

  interface ROMIfc;
    interface Get#(TL_AReq) tlIn;
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkROM(ROMIfc);
    RegFile#(Bit#(10), Bit#(32)) mem <- mkRegFileLoad("rom.hex", 0, 1023);

    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule handleRead (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      let addr = req.address[11:2];
      let data = mem.sub(addr);

      $display("[ROM] Read from addr %x: %x", req.address, data);

      respFifo.enq(TL_DResp { success: True, data: data });
    endrule

    interface Get tlIn = toGet(reqFifo);
    interface Get tlRespOut = toGet(respFifo);

  endmodule
endpackage