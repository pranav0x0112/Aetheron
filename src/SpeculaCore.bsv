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
  typedef Bit#(5) RegIndex;

  typedef struct {
    Bit #(7) opcode;
    RegIndex rd;
    RegIndex rs1;
    RegIndex rs2;
    Bit #(3) funct3;
    Bit #(7) funct7;
    Bit #(32) imm;
    Bit #(32) nextPC;
    Instruction raw;
  } Decoded deriving (Bits, FShow);

  function Decoded decode(Instruction i, Bit#(32) pc);
    Decoded d;
    d.opcode = i[6:0];
    d.rd = i[11:7];
    d.funct3 = i[14:12];
    d.rs1 = i[19:15];
    d.rs2 = i[24:20];
    d.funct7 = i[31:25];
    d.nextPC = pc + 4;
    d.raw = i;

    case (d.opcode)
      7'b1100011: d.imm = signExtend({i[31], i[7], i[30:25], i[11:8], 1'b0}); // branch
      7'b0100011: d.imm = signExtend({i[31:25], i[11:7]});   // S‑type (store)
      7'b1101111: d.imm = signExtend({i[31], i[19:12], i[20],     i[30:21], 1'b0}); // J‑type (JAL)
      7'b0110111, 7'b0010111: d.imm = signExtend(i[31:12]); // U‑type (AUIPC)
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
    Reg#(Bool) reachedEndPC <- mkReg(False);
    Reg#(Bit#(32)) endWaitCycles <- mkReg(0);

    function Word rfRead(RegIndex idx);
      return (idx == 0) ? 0 : rf.sub(idx);
    endfunction
    
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

    rule checkEndProgram(pipelineStarted);
      if (pc >= 40) begin
        reachedEndPC <= True;
      end

      if (reachedEndPC) begin
        endWaitCycles <= endWaitCycles + 1;

        if(endWaitCycles >= 20) begin
          done <= True;
          $display("=== Program execution complete (waited %0d extra cycles) ===", endWaitCycles);
        end else begin
          done <= False;
        end
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
      id_ex_valid <= True;
      id_ex_val1 <= rfRead(d.rs1);
      id_ex_val2 <= rfRead(d.rs2);

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
      Bit#(32) effAddr = val1 + d.imm;   // rs1 + imm
      Bool isLW = (d.opcode == 7'b0000011) && (d.funct3 == 3'b010);
      Bool isSW = (d.opcode == 7'b0100011) && (d.funct3 == 3'b010);


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

          7'b0000011: begin // LOADs
            if (isLW) begin
              result = effAddr;
              storeVal = val2; 
              isLoad = True;
              writeReg = True;
              $display("[EX] LW: addr=0x%h -> load into x%0d", effAddr, d.rd);
            end else begin
              $display("[EX] Unsupported LOAD funct3 %b", d.funct3);
              writeReg = False;
            end
          end

          7'b0100011: begin // STOREs
            if (isSW) begin
              result = effAddr;
              storeVal = val2;
              writeReg = False;
              $display("[EX] SW: addr=0x%h  data=0x%h", effAddr, storeVal);
            end else begin
              $display("[EX] Unsupported STORE funct3 %b", d.funct3);
              writeReg = False;
            end
          end

          7'b0110111: begin // LUI
            result = d.imm << 12;
            $display("[EX] LUI: imm=0x%h -> result=0x%h", d.imm, result);
          end

          7'b0010111: begin // AUIPC
            result = d.nextPC + (d.imm << 12);
            $display("[EX] AUIPC: pc=0x%h + imm<<12=0x%h -> result=0x%h", d.nextPC, d.imm << 12, result);
          end

          7'b1101111: begin // JAL
            result = d.nextPC; 
            nextPC <= d.nextPC + d.imm - 4;
            flush <= True;
            $display("[EX] JAL: rd=%0d gets %h, jumping to %h", d.rd, result, d.nextPC + d.imm);
          end

          7'b1100111: begin // JALR
            if (d.funct3 == 3'b000) begin
              result = d.nextPC;
              nextPC <= (val1 + d.imm) & ~1;
              flush <= True;
              $display("[EX] JALR: rd=%0d gets %h, jumping to %h", d.rd, result, (val1 + d.imm) & ~1);
            end else begin
              $display("[EX] Unsupported JALR funct3: %b", d.funct3);
              writeReg = False;
            end
          end

          default: begin
            $display("[EX] Unsupported opcode: %b", d.opcode);
            writeReg = False;
          end
        endcase
      end

      ex_mem <= tuple4(result, d.rd, isLoad, storeVal);
      ex_mem_valid <= True;
      mem_outstanding <= isLoad; 

      if (writeReg && !isLoad) begin
        mem_wb <= tuple3(result, d.rd, True);
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
      let data = tpl_1(mem_wb);
      let rd   = tpl_2(mem_wb);

      if (rd != 0) begin
        rf.upd(rd, data);
        $display("[WB] Wrote x%0d = %h", rd, data);
      end else
        $display("[WB] Ignoring write to x0");

      mem_wb <= tuple3(0, 0, False);
    endrule

  endmodule
endpackage