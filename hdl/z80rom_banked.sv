`include "Z80Bus.vh"

module z80rom_banked #(
    parameter string FNAME,
    parameter BANK_W,
    parameter ADDR_W,
    parameter DATA_W = 8,
    parameter EMPTY_FILL_ZERO = 0
) (
    input logic             clk,
    input logic             ena,
    input logic[BANK_W-1:0] banksel,
    input Z80MasterBus      ibus,
    output Z80SlaveBus      obus
);

assign obus.mwait = 1'b1;

rom#(FNAME, BANK_W + ADDR_W, DATA_W, EMPTY_FILL_ZERO)
rom_imp (
    .clk(clk),
    .ena(ena),
    .addr({banksel, ibus.addr[ADDR_W-1:0]}),
    .dout(obus.dslave)
);

endmodule : z80rom_banked
