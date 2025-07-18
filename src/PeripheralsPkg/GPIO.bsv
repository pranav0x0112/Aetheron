package GPIO;

  import GetPut::*;
  import FIFOF::*;
  import TLTypes::*;

  interface GPIOIfc;
    interface Put#(TL_AReq) tlIn; 
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkGPIO(GPIOIfc);

    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule handleWrite if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      if (req.address >= 32'h40000000 && req.address < 32'h40001000) begin
        $display("[GPIO] LED State update request at address: %08x", req.address);
      end else begin
        $display("[GPIO] Invalid address: %08x", req.address);
      end

      respFifo.enq(TL_DResp {
        success: True,
        data: 32'h00000000
      });
    endrule

    interface Put tlIn = toPut(reqFifo);
    interface Get tlRespOut = toGet(respFifo);

  endmodule
endpackage