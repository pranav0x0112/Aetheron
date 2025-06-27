package GPIO;

  import GetPut::*;
  import FIFOF::*;
  import TLTypes::*;

  interface GPIOIfc;
    interface Get#(TL_AReq) reqIn;
  endinterface

  module mkGPIO(GPIOIfc);

    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;

    rule handleWrite if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      if (req.address == 32'h40000000) begin
        $display("[GPIO] LED State update request at address: %08x", req.address);
      end else begin
        $display("[GPIO] Invalid address: %08x", req.address);
      end
    endrule

    interface Get reqIn = toGet(reqFifo);

  endmodule
endpackage