package UART;

  import GetPut::*;
  import FIFOF::*;
  import TLTypes::*;

  interface UARTIfc;
    interface Put#(TL_AReq) tlIn; 
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkUART(UARTIfc);

    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule handleWrite if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      if (req.address == 32'h40001000) begin
        $display("[UART] Transmit data: %08x", req.data);
      end else begin
        $display("[UART] Invalid address: %08x", req.address);
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