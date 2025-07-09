package AetheronTop;

  import CPUStub::*;
  import TileLinkPkg::*;
  import PeripheralsPkg::*;
  import Connectable::*;
  import MemoryPkg::*;
  import RAM::*;

  module mkAetheronTop(Empty);

    let cpu <- mkCPUStub;
    let master <- mkTLMasterXactor;
    let slave <- mkTLSlaveXactor;
    let gpio <- mkGPIO;
    let rom <- mkROM;
    let ram <- mkRAM;

    mkConnection(cpu.reqOut, master.reqIn);
    mkConnection(master.respOut, cpu.respIn);
    mkConnection(master.tlOut, slave.tlIn);
    mkConnection(slave.respOut, master.tlRespIn);
    mkConnection(slave.periphOut, gpio.reqIn);
    mkConnection(slave.romOut, rom.tlIn);
    mkConnection(rom.tlRespOut, slave.romIn);
    mkConnection(slave.ramOut, ram.tlIn);
    mkConnection(ram.tlRespOut, slave.ramIn);

  endmodule

endpackage