package AetheronTop;

  import CPUStub::*;
  import TileLinkPkg::*;
  import PeripheralsPkg::*;
  import Connectable::*;

  module mkAetheronTop(Empty);

    let cpu <- mkCPUStub;
    let master <- mkTLMasterXactor;
    let slave <- mkTLSlaveXactor;
    let gpio <- mkGPIO;

    mkConnection(cpu.reqOut, master.reqIn);
    mkConnection(master.respOut, cpu.respIn);
    mkConnection(master.tlOut, slave.tlIn);
    mkConnection(slave.tlRespOut, master.tlRespIn);
    mkConnection(slave.periphOut, gpio.reqIn);

  endmodule

endpackage