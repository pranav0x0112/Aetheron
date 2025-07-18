package PeripheralsPkg;

  import GPIO::*;
  import UART::*;
  import TLTypes::*;
  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;
  import Connectable::*;

  export GPIO::*;
  export UART::*;
  export PeripheralsIfc(..); 
  export mkPeripherals;  

  interface PeripheralsIfc;
    interface Put#(TL_AReq) tlIn;  
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkPeripherals(PeripheralsIfc);
    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;
    FIFOF#(TL_AReq) gpioReqQ <- mkFIFOF;
    FIFOF#(TL_AReq) uartReqQ <- mkFIFOF;

    GPIOIfc gpio <- mkGPIO;
    UARTIfc uart <- mkUART;

    mkConnection(toGet(gpioReqQ), gpio.tlIn);  
    mkConnection(toGet(uartReqQ), uart.tlIn);  
    function Bool isGPIO(Bit#(32) addr);
      return addr >= 32'h40000000 && addr < 32'h40001000;
    endfunction

    function Bool isUART(Bit#(32) addr);
      return addr >= 32'h40001000 && addr < 32'h40002000;
    endfunction

    function Bool isTIMER(Bit#(32) addr);
      return addr >= 32'h40002000 && addr < 32'h40003000;
    endfunction

    rule routeGPIO (reqFifo.notEmpty && isGPIO(reqFifo.first.address));
      gpioReqQ.enq(reqFifo.first);
      reqFifo.deq;
    endrule

    rule routeUART (reqFifo.notEmpty && isUART(reqFifo.first.address));
      uartReqQ.enq(reqFifo.first);
      reqFifo.deq;
    endrule

    rule forwardGPIOResp;
      let resp <- gpio.tlRespOut.get;
      respFifo.enq(resp);
    endrule

    rule forwardUARTResp;
      let resp <- uart.tlRespOut.get;
      respFifo.enq(resp);
    endrule

    interface Put tlIn = toPut(reqFifo);  
    interface Get tlRespOut = toGet(respFifo);
  endmodule
endpackage