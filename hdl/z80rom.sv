`include "Z80Bus.vh"

module z80rom #(
    parameter string FNAME,
    parameter ADDR_W,
    parameter DATA_W = 8
) (
    input logic         clk,
    input logic         ena,
    input Z80MasterBus  ibus,
    output Z80SlaveBus  obus
);

assign obus.mwait = 1'b1;

rom#(FNAME, ADDR_W, DATA_W)
rom_imp (
    .clk(clk),
    .ena(ena),
    .addr(ibus.addr),
    .dout(obus.dslave)
);

endmodule : z80rom
