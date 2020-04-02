module program_rom_wrapper_banked (
    input logic clk,
    input logic ena,
    input logic[1:0] banksel,
    input Z80MasterBus ibus,
    output Z80SlaveBus obus
);

assign obus.mwait = 1'b1;

cpu_program_banked_rom inst (
    .clka(clk),
    .ena(ena),
    .addra({banksel, ibus.addr[14:0]}),
    .douta(obus.dslave)
);

endmodule
