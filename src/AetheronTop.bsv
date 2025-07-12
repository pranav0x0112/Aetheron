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

    Reg#(Bool) cpuDoneDetected <- mkReg(False);
    Reg#(Bit#(32)) waitCycles <- mkReg(0);
    let extraCycles = 20;

    rule gracefulShutdown;
      if (cpu.isDone) cpuDoneDetected <= True;

      if (cpuDoneDetected) begin
        waitCycles <= waitCycles + 1;

        if (waitCycles >= extraCycles) begin
          $display("[Top] CPU done; waited %0d cycles for outstanding TL traffic",waitCycles);
          $finish;
        end
      end
    endrule

    mkConnection(cpu.reqOut, master.reqIn);
    mkConnection(master.respOut, cpu.respIn);
    mkConnection(master.tlOut, slave.tlIn);
    mkConnection(slave.respOut, master.tlRespIn);
    mkConnection(slave.periphOut, peripherals.tlIn);
    mkConnection(peripherals.tlRespOut, master.tlRespIn);
    mkConnection(slave.romOut, rom.tlIn);         
    mkConnection(rom.tlRespOut, slave.romIn);
    mkConnection(slave.ramOut, ram.tlIn);     
    mkConnection(ram.tlRespOut, slave.ramIn);

  endmodule

endpackage