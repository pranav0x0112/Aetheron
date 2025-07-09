package PeripheralsPkg;

  import GPIO::*;
  import UART::*;
  import TLTypes::*;
  import FIFO::*;
  import FIFOF::*;
  import GetPut::*;

  export GPIO::*;
  export UART::*;

  interface PeripheralsIfc;
    interface Get#(TL_AReq) tlIn;
    interface Get#(TL_DResp) tlRespOut;
  endinterface

  module mkPeripherals(PeripheralsIfc);
    FIFOF#(TL_AReq) reqFifo <- mkFIFOF;
    FIFOF#(TL_DResp) respFifo <- mkFIFOF;
    FIFOF#(TL_AReq) gpioReqQ <- mkFIFOF;
    FIFOF#(TL_AReq) uartReqQ <- mkFIFOF;

    GPIOIfc gpio <- mkGPIO;
    UARTIfc uart <- mkUART;

    gpio.tlIn = toGet(gpioReqQ);
    uart.tlIn = toGet(uartReqQ);

    function Bool isGPIO(Bit#(32) addr);
      return addr[31:28] == 4'h2;
    endfunction

    function Bool isUART(Bit#(32) addr);
      return addr[31:28] == 4'h1;
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

    interface Get tlIn = toGet(reqFifo);
    interface Get tlRespOut = toGet(respFifo);

  endmodule
endpackage