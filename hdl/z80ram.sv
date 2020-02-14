`include "Z80Bus.vh"

module z80ram #(
    parameter ADDR_W,
    parameter DATA_W = 8
) (
    input logic         clk,
    input logic         ena,
    input Z80MasterBus  ibus,
    output Z80SlaveBus  obus
);

assign obus.mwait = 1'b1;

ram#(ADDR_W, DATA_W)
ram_imp (
    .clk(clk),
    .ena(ena),
    .rd(~ibus.rdn),
    .wr(~ibus.wrn),
    .addr(ibus.addr[ADDR_W-1:0]),
    .din(ibus.dmaster[DATA_W-1:0]),
    .dout(obus.dslave[DATA_W-1:0])
);

endmodule : z80ram

