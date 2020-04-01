module program_rom_wrapper (
    input logic clk,
    input logic ena,
    input Z80MasterBus ibus,
    output Z80SlaveBus obus

`ifdef ARM_LOADER
    ,
    input logic clkext,
    input logic enaext,
    input logic weext,
    input logic[13:0] addrext,
    input logic[7:0] dinext,
    output logic[7:0] doutext
`endif

);

assign obus.mwait = 1'b1;

`ifdef ARM_LOADER
cpu_program_rom_dp inst (
    .clka(clkext),
    .ena(enaext),
    .wea(weext),
    .addra(addrext),
    .dina(dinext),
    .douta(doutext),

    .clkb(clk),
    .enb(ena),
    .web(1'b0),
    .addrb(ibus.addr[13:0]),
    .dinb(8'b00),
    .doutb(obus.dslave)
);
`else
cpu_program_rom inst (
    .clka(clk),
    .ena(ena),
    .addra(ibus.addr[13:0]),
    .douta(obus.dslave)
);
`endif

endmodule
