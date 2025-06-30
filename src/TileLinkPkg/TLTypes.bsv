package TLTypes;

  typedef struct{
    Bit#(32) address;
  }  TL_AReq deriving (Bits, Eq, FShow);

  typedef struct {
    Bool success;
    Bit#(32) data;
  } TL_DResp deriving (Bits, Eq, FShow);

endpackage