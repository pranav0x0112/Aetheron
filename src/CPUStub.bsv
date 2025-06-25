package CPUStub;

  import TileLink::TLTypes::*;

  interface CPUStubIfc;
    interface Put#(TL_AReq) reqOut;
    interface Get#(TL_DResp) respIn;
  endinterface

  module mkCPUStub(CPUStubIfc);

    Reg#(Bool) hasSent <- mkReg(False);
    FIFO#(TL_DResp)    dRespFifo <- mkFIFO;

    interface Put reqOut;
      method Bool canPut = !hasSent;
      method Action put(TL_AReq req);
        if(!hasSent)
          begin
            $display("[CPU] Put to addr %x with data %x", req.address, req.data);
            hasSent <= True;
          end
      endmethod
    endinterface

    interface Get respIn = toGet(dRespFifo);
  endmodule
  
endpackage
    

