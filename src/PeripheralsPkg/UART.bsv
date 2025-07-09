package UART;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface UARTIfc;
    interface Get#(TL_AReq) tlIn;
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkUART(UARTIfc);
    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule handleUART(reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      Bit#(32) addr = req.address;
      Bit#(32) data = req.data;

      if (req.opcode == Put && addr[3:0] == 4'h0) begin
        Bit#(8) ch = data[7:0];
        $write("[UART] TX: '");
        if (ch >= 32 && ch <= 126)
          $write("%c", ch);
        else
          $write(".");
        $display("' (0x%02x)", ch);
      end

      respFifo.enq(TL_DResp {
        success: True, 
        data: 32'h00000000
      });
    endrule

    interface Get tlIn = toGet(reqFifo);
    interface Get tlRespOut = toGet(respFifo);
  
  endmodule
endpackage
