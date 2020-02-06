module z80_rom_wrapper(
    input logic clk,
    input logic ena,
    input Z80MasterBus ibus,
    output Z80SlaveBus obus
);

assign obus.mwait = 1'b1;

z80_rom_ip rom (
    .clka(clk),
    .ena(ena),
    .addra(ibus.addr[14:0]),
    .douta(obus.dslave)
);

endmodule
