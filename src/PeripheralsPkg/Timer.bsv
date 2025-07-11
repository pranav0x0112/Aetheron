package Timer;

  import GetPut::*;
  import FIFOF::*;
  import TLTypes::*;

  interface TimerIfc;
    interface Put#(TL_AReq) tlIn;
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkTimer(TimerIfc);

    Reg#(Bit#(32)) cycleCounter <- mkReg(0);
    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;

    rule tick;
      cycleCounter <= cycleCounter + 1;
    endrule

    rule handleRead if (reqFifo.notEmpty);
      let req = reqFifo.first;
      reqFifo.deq;

      Bool ok = False;
      Bit#(32) response = 32'h00000000;

      if (req.opcode == Get && req.address == 32'h10018000) begin
        response = cycleCounter;
        ok = True;
        $display("[TIMER] Read cycle count = %0d", cycleCounter);
      end else begin
        $display("[TIMER] Invalid access: addr=%h opcode=%0d", req.address, req.opcode);
      end

      respFifo.enq(TL_DResp { success: ok, data: response });
    endrule

    interface Put tlIn = toPut(reqFifo);
    interface Get tlRespOut = toGet(respFifo);
    
  endmodule
endpackage