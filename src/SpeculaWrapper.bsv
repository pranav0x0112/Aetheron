package SpeculaWrapper;

  import Vector::*;
  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import TLTypes::*;
  import SpeculaCore::*;
  import RegFile::*;

  interface CPUIfc;
    interface Get#(TL_AReq) reqOut;
    interface Put#(TL_DResp) respIn;
    method Bool isDone();
  endinterface

  module mkSpeculaCPU(CPUIfc);
    FIFOF#(TL_AReq) tlReqQ <- mkFIFOF;
    FIFOF#(TL_DResp) tlRespQ <- mkFIFOF;

    Reg#(Bit#(32)) pc <- mkReg(0);
    RegFile#(RegIndex, Word) rf <- mkRegFileFull;
    Reg#(Bool) flush <- mkReg(False);
    Reg#(Bit#(32)) nextPC <- mkReg(0);
    Reg#(Bool) done <- mkReg(False);

    Reg#(Bit#(32)) if_id_pc <- mkReg(0);
    Reg#(Instruction) if_id_instr <- mkReg(0);
    Reg#(Decoded) id_ex_decoded <- mkReg(?); 
    Reg#(Tuple4#(Bit#(32), RegIndex, Bool, Bit#(32))) ex_mem <- mkReg(tuple4(0, 0, False, 0));
    Reg#(Tuple3#(Bit#(32), RegIndex, Bool)) mem_wb <- mkReg(tuple3(0, 0, False));

    Reg#(Bool) id_ex_valid <- mkReg(False);
    Reg#(Bool) ex_mem_valid <- mkReg(False);
    Reg#(Bool) waitingForResp <- mkReg(False);

    rule debugTL;
      if (tlReqQ.notEmpty) begin
        $display("[TL Debug] Request pending: opcode=%0d, addr=%h", tlReqQ.first.opcode, tlReqQ.first.address);
      end
    endrule

    mkSpeculaCoreInternal(rf, pc, flush, nextPC, done, if_id_pc, if_id_instr, id_ex_decoded, ex_mem, mem_wb, id_ex_valid, ex_mem_valid, waitingForResp, tlReqQ, tlRespQ);

    interface Get reqOut = toGet(tlReqQ);
    interface Put respIn = toPut(tlRespQ);
    
    method Bool isDone();
      return done;
    endmethod
    
  endmodule
endpackage