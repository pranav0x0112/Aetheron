package SpeculaCore;

  import Vector::*;
  import RegFile::*;
  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import ClientServer::*;
  import TLTypes::*;

  typedef Bit#(32) Word;
  typedef Bit#(32) Instruction;
  typedef Bit#(32) RegIndex;

  typdef struct {
    Bit #(7) opcode;
    RegIndex rd;
    RegIndex rs1;
    RegIndex rs2;
    Bit #(3) funct3;
    Bit #(7) funct7;
    Bit #(32) imm;
    Bit #(32) nextPC:
    Instruction raw;
  } Decoded deriving (Bits, FShow);

  function Decoded decode(Instruction i, Bit#(32) pc);
    Decoded d;
    d.opcode = i[6:0];
    d.rd = unpack(i[11:7]);
    d.funct3 = i[14:12];
    d.rs1 = unpack(i[19:15]);
    d.rs2 = unpack(i[24:20]);
    d.funct7 = i[31:25];
    d.nextPC = pc + 4;
    d.raw = i;

    case (d.opcode)
      7'b1100011: d.imm = signExtend({i[31], i[7], i[30:25], i[11:8], 1'b0}); // branch
      default: d.imm = signExtend(i[31:20]); // I-type or default
    endcase

    return d;
  endfunction

  (* descending_urgency = "init_rf, stage_WB, stage_MEM_resp, stage_MEM, stage_EX, stage_ID, stage_IF_commit, stage_IF_resp, stage_IF_req, countCycles, checkStuckState" *)

  module mkSpeculaCoreInternal#(RegFile#(RegIndex, Word) rf, Reg#(Bit#(32)) pc, Reg#(Bool) flush, Reg#(Bit#(32)) nextPC, Reg#(Bool) done, Reg#(Bit#(32)) if_id_pc, Reg#(Instruction) if_id_instr, Reg#(Decoded) id_ex_decoded, Reg#(Tuple4#(Bit#(32), RegIndex, Bool, Bit#(32))) ex_mem, Reg#(Tuple3#(Bit#(32), RegIndex, Bool)) mem_wb, Reg#(Bool) id_ex_valid, Reg#(Bool) ex_mem_valid, Reg#(Bool) waitingForResp, FIFOF#(TL_AReq) tlReqQ, FIFOF#(TL_DResp) tlRespQ) ();

    Reg#(Bit#(5)) initCounter <- mkReg(0);
    Reg#(Bool) rf_init_done <- mkReg(False);
    Reg#(Bool) pipelineStarted <- mkReg(False);

    Reg#(Bool) mem_outstanding <- mkReg(False);
    Reg#(Word) id_ex_val1 <- mkReg(0);
    Reg#(Word) id_ex_val2 <- mkReg(0);
    Reg#(Bool) if_waiting <- mkReg(False);
    Reg#(Bool) if_respReady <- mkReg(False);
    Reg#(Instruction) if_instrBuf <- mkReg(0);

    Reg#(Bit#(32)) cycleCount <- mkReg(0);
    Reg#(Bit#(32)) waitCycles <- mkReg(0);
    
    rule checkStuckState(if_waiting);
      let current_wait = waitCycles + 1;
      waitCycles <= current_wait;

      if (current_wait % 1000 == 0) begin
        $display("[CPU Debug] Waiting for %0d cycles for instruction at PC=%h", current_wait, pc);
        $display("[CPU Debug] tlReqQ empty: %b, tlRespQ empty: %b", !tlReqQ.notEmpty, !tlRespQ.notEmpty);
      end

      if (current_wait > 5000) begin
        $display("ERROR: CPU stuck waiting for instruction response for %0d cycles", current_wait);
        $display("Current state: PC=%h, if_waiting=%b", pc, if_waiting);
        if_waiting <= False;
      end
    endrule

    rule init_rf(!rf_init_done);
      case(initCounter)
        0: begin rf.upd(1, 10); $display("[INIT] Setting x1 = 10"); end
        1: begin rf.upd(2, 20); $display("[INIT] Setting x2 = 20"); end
        2: begin rf.upd(5, 100); $display("[INIT] Setting x5 = 100"); end
        3: begin rf.upd(6, 60); $display("[INIT] Setting x6 = 60"); end
        4: begin
          rf_init_done <= True;
          $display("=== Register file initialized ===");
        end
      endcase

      initCounter <= initCounter + 1;
    endrule

    rule triggerPipeline(rf_init_done && !pipelineStarted);
      pipelineStarted <= True;
      $display("=== Pipeline started ===");
    endrule

    rule countCycles(pipelineStarted);
      cycleCount <= cycleCount + 1;
      if (cycleCount % 100 == 0) begin
        $display("--- Cycle %0d status ---", cycleCount);
        $display("  PC: %0d", pc);
        $display("  if_waiting: %b, if_respReady: %b", if_waiting, if_respReady);
        $display("  id_ex_valid: %b, ex_mem_valid: %b", id_ex_valid, ex_mem_valid);
        $display("  waitingForResp: %b, done: %b", waitingForResp, done);
        $display("  tlReqQ empty: %b, tlRespQ empty: %b", !tlReqQ.notEmpty, !tlRespQ.notEmpty);
      end
    endrule

    // === IF Stage ===
    rule stage_IF_req(pipelineStarted && !done && !if_waiting && !if_respReady && tlReqQ.notFull());
      TL_AReq req = TL_AReq { opcode: Get, address: flush ? nextPC : pc, data: 0 };
      tlReqQ.enq(req);
      if_waiting <= True;
      waitCycles <= 0;
      $display("[IF] Enqueued instruction request: opcode=%0d, addr=%h", req.opcode, req.address);
    endrule

    rule stage_IF_resp(if_waiting && tlRespQ.notEmpty);
      let resp = tlRespQ.first; tlRespQ.deq;
      if_instrBuf <= resp.data;
      if_waiting <= False;
      if_respReady <= True;
      waitCycles <= 0; 
      $display("[IF] Received instruction: %h", resp.data);
    endrule

    rule stage_IF_commit(if_respReady);
      if_id_instr <= if_instrBuf;
      if_id_pc <= flush ? nextPC : pc;
      if (!flush) pc <= pc + 4;
      flush <= False;
      if_respReady <= False;

      $display("[IF] Committed instruction %h from pc = %0d", if_instrBuf, flush ? nextPC : pc);

      if (pc >= 40) begin
        done <= True;
        $display("=== Program execution complete ===");
      end
    endrule

    // === ID Stage ===
    rule stage_ID(pipelineStarted && !done && !id_ex_valid && if_id_instr != 0);
      Decoded d = decode(if_id_instr, if_id_pc);
      id_ex_decoded <= d;
      id_ex_val1 <= rf.sub(d.rs1);
      id_ex_val2 <= rf.sub(d.rs2);
      id_ex_valid <= True;

      $display("[ID] Decoded at pc=%0d: opcode=%b rd=%0d rs1=%0d rs2=%0d imm=0x%h", if_id_pc, d.opcode, d.rd, d.rs1, d.rs2, d.imm);
      $display("[ID] Read values: rs1(x%0d)=%0d, rs2(x%0d)=%0d", d.rs1, rf.sub(d.rs1), d.rs2, rf.sub(d.rs2));
    endrule

    // === EX Stage ===
    rule stage_EX(pipelineStarted && !done && id_ex_valid && !ex_mem_valid);
      let d = id_ex_decoded;
      let val1 = id_ex_val1;
      let val2 = id_ex_val2;
      Word result = 0;
      Bool isLoad = False;
      Bit#(32) storeVal = 0;
      Bool writeReg = True;

      if (d.opcode == 0 || d.raw == 32'h00000000) begin
        $display("[EX] Skipping NOP");
        writeReg = False;
      end else begin
        case (d.opcode)
          7'b0010011: begin // I-type
            case (d.funct3)
              3'b000: begin // ADDI
                result = val1 + d.imm;
                $display("[EX] ADDI: %0d + %0d = %0d", val1, d.imm, result);
              end
              default: begin
                result = 32'hDEADDEAD;
                $display("[EX] Unsupported I-type funct3: %b", d.funct3);
                writeReg = False;
              end
            endcase
          end

          7'b0110011: begin // R-type
            case ({d.funct7, d.funct3})
              {7'b0000000, 3'b000}: begin // ADD
                result = val1 + val2;
                $display("[EX] ADD: %0d + %0d = %0d", val1, val2, result);
              end
              {7'b0100000, 3'b000}: begin // SUB
                result = val1 - val2;
                $display("[EX] SUB: %0d - %0d = %0d", val1, val2, result);
              end
              {7'b0000000, 3'b110}: begin // OR
                result = val1 | val2;
                $display("[EX] OR: %h | %h = %h", val1, val2, result);
              end
              {7'b0000000, 3'b100}: begin // XOR
                result = val1 ^ val2;
                $display("[EX] XOR: %h ^ %h = %h", val1, val2, result);
              end
              {7'b0000000, 3'b001}: begin // SLL
                result = val1 << val2[4:0];
                $display("[EX] SLL: %h << %0d = %h", val1, val2[4:0], result);
              end
              default: begin
                result = 32'hDEADDEAD;
                $display("[EX] Unsupported R-type instruction: funct7=%b, funct3=%b", d.funct7, d.funct3);
                writeReg = False;
              end
            endcase
          end

          7'b1100011: begin // Branch
            case (d.funct3)
              3'b000: begin // BEQ
                if (val1 == val2) begin
                  flush <= True;
                  nextPC <= d.nextPC + d.imm - 4; 
                  $display("[EX] BEQ taken: %0d == %0d, branching to %0d", val1, val2, d.nextPC + d.imm);
                end else begin
                  $display("[EX] BEQ not taken: %0d != %0d", val1, val2);
                end
              end
              default: $display("[EX] Unsupported branch funct3: %b", d.funct3);
            endcase
            writeReg = False;
          end

          default: begin
            $display("[EX] Unsupported opcode: %b", d.opcode);
            writeReg = False;
          end
        endcase
      end

      if (writeReg) begin
        ex_mem <= tuple4(result, d.rd, isLoad, storeVal);
        ex_mem_valid <= True;
        mem_outstanding <= isLoad;
        $display("[EX] Result: %h for rd=%0d, isLoad=%d", result, d.rd, isLoad);
      end else begin
        ex_mem_valid <= False;
        mem_outstanding <= False;
      end
      id_ex_valid <= False;
    endrule

    // === MEM Request ===
    rule stage_MEM(pipelineStarted && !done && !waitingForResp && ex_mem_valid && tlReqQ.notFull());
      let {addr, rd, isLoad, storeVal} = ex_mem;
      TL_AReq req;

      if (isLoad) begin
        req = TL_AReq { opcode: Get, address: addr, data: 0 };
        waitingForResp <= True;
        $display("[MEM] Load request for address %h", addr);
      end else begin
        req = TL_AReq { opcode: Put, address: addr, data: storeVal };
        mem_wb <= tuple3(addr, rd, True);
        mem_outstanding <= False;
        $display("[MEM] Store request: addr=%h, data=%h", addr, storeVal);
      end

      tlReqQ.enq(req);
      ex_mem_valid <= False;
    endrule

    // === MEM Response ===
    rule stage_MEM_resp(pipelineStarted && waitingForResp && tlRespQ.notEmpty);
      let resp = tlRespQ.first; tlRespQ.deq;
      let ex_mem_tmp = ex_mem;
      let rd = tpl_2(ex_mem_tmp);
      mem_wb <= tuple3(resp.data, rd, True);
      waitingForResp <= False;
      $display("[MEM] Received response: data=%h for rd=%0d", resp.data, rd);
    endrule

    // === WB Stage ===
    rule stage_WB(pipelineStarted && !done && tpl_3(mem_wb));
      let {val, rd, valid} = mem_wb;
      if (valid && rd != 0) begin
        rf.upd(rd, val);
        $display("[WB] Writing %h to register x%0d", val, rd);
      end
      mem_wb <= tuple3(0, 0, False);
    endrule

  endmodule
endpackage