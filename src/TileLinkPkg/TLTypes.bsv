package TLTypes;

  typedef struct{
    Bit#(32) address;
    Bit#(32) data;
    TL_Opcode opcode;
  }  TL_AReq deriving (Bits, Eq, FShow);

  typedef struct {
    Bool success;
    Bit#(32) data;
  } TL_DResp deriving (Bits, Eq, FShow);

  typedef enum {
    Get = 0,
    Put = 1
  } TL_Opcode deriving (Bits, Eq, FShow);

endpackage