package AetheronTop;

  import SpeculaWrapper::*;
  import TileLinkPkg::*;
  import PeripheralsPkg::*;
  import Connectable::*;
  import MemoryPkg::*;
  import RAM::*;
  import GetPut::*;

  module mkAetheronTop(Empty);

    let cpu <- mkSpeculaCPU;
    let master <- mkTLMasterXactor;
    let slave <- mkTLSlaveXactor;
    let peripherals <- mkPeripherals;
    let rom <- mkROM;
    let ram <- mkRAM;

    Reg#(Bit#(32)) topCycleCount <- mkReg(0);
    
    rule countTopCycles;
      topCycleCount <= topCycleCount + 1;
      if (topCycleCount % 200 == 0) begin
        $display("=== Top level cycle count: %0d ===", topCycleCount);
      end
    endrule

    rule debugMaster;
      if (cpu.isDone) begin
        $display("[Top] CPU execution complete, finishing simulation");
        $finish;
      end
    endrule

    mkConnection(cpu.reqOut, master.reqIn);
    mkConnection(master.respOut, cpu.respIn);
    mkConnection(master.tlOut, slave.tlIn);
    mkConnection(slave.respOut, master.tlRespIn);
    mkConnection(slave.periphOut, peripherals.tlIn);
    mkConnection(slave.romOut, rom.tlIn);         
    mkConnection(rom.tlRespOut, slave.romIn);
    mkConnection(slave.ramOut, ram.tlIn);     
    mkConnection(ram.tlRespOut, slave.ramIn);

  endmodule

endpackage