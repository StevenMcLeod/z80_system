`ifndef Z80BUS_VH
`define Z80BUS_VH

typedef struct packed {
    logic[15:0] addr;
    logic[7:0]  dmaster;
    logic       rdn, wrn;
    logic       inta;
} Z80MasterBus;

typedef struct packed {
    logic[7:0]  dslave;
    logic       mwait;
} Z80SlaveBus;

`endif