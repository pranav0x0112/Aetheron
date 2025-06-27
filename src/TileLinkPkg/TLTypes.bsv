package TLTypes;

  typedef struct{
    Bit#(32) address;
  }  TL_AReq deriving (Bits, Eq, FShow);

  typedef struct {
    Bool success;
  } TL_DResp deriving (Bits, Eq, FShow);

endpackage