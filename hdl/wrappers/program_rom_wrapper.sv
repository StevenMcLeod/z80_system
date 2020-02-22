module program_rom_wrapper (
    input logic clk,
    input logic ena,
    input Z80MasterBus ibus,
    output Z80SlaveBus obus
);

assign obus.mwait = 1'b1;

cpu_program_rom inst (
    .clka(clk),
    .ena(ena),
    .addra(ibus.addr[13:0]),
    .douta(obus.dslave)
);

endmodule
