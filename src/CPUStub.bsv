package CPUStub;

  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;

  interface CPUStubIfc;
    interface Get#(TL_AReq) reqOut; 
    interface Put#(TL_DResp) respIn;
  endinterface

  module mkCPUStub(CPUStubIfc);

    Reg#(Bit#(32)) pc <- mkReg(0);
    Reg#(UInt#(1)) mode <- mkReg(0);        // 0 = RAM test, 1 = ROM fetch
    Reg#(UInt#(2)) state <- mkReg(0);       // RAM test FSM
    Reg#(Bool) sentReq <- mkReg(False);

    FIFOF#(TL_DResp) dRespFifo <- mkFIFOF;
    FIFOF#(TL_AReq)  aReqFifo  <- mkFIFOF;

    // RAM test: Write → Read → Check
    rule writeToRAM (mode == 0 && state == 0);
      TL_AReq req = TL_AReq {
        address: 32'h80000000,
        data: 32'hDEADBEEF,
        opcode: Put
      };
      aReqFifo.enq(req);
      $display("[CPUStub] Writing to RAM at 0x80000000: %08x", req.data);
      state <= 1;
    endrule

    rule readFromRAM (mode == 0 && state == 1);
      TL_AReq req = TL_AReq {
        address: 32'h80000000,
        data: 0,
        opcode: Get
      };
      aReqFifo.enq(req);
      $display("[CPUStub] Reading from RAM at 0x80000000...");
      state <= 2;
    endrule

    rule recvRAMResp (mode == 0 && state == 2 && dRespFifo.notEmpty);
      let resp = dRespFifo.first;
      dRespFifo.deq;
      $display("[CPUStub] Got RAM response: %08x", resp.data);
      state <= 3;
    endrule

    rule switchToFetch (mode == 0 && state == 3);
      $display("[CPUStub] RAM test done. Switching to instruction fetch mode.");
      mode <= 1;
    endrule

    // ROM instruction fetch loop
    rule sendFetch (mode == 1 && !sentReq);
      TL_AReq req = TL_AReq {
        address: pc,
        data: 0,
        opcode: Get
      };
      aReqFifo.enq(req);
      $display("[CPU] Fetching instruction at addr: %08x", pc);
      sentReq <= True;
    endrule

    rule recvInstr (mode == 1 && sentReq && dRespFifo.notEmpty);
      let resp = dRespFifo.first;
      dRespFifo.deq;
      $display("[CPU] Got instruction: %08x", resp.data);
      pc <= pc + 4;
      sentReq <= False;
    endrule

    interface Get reqOut = toGet(aReqFifo);
    interface Put respIn = toPut(dRespFifo);

  endmodule
endpackage