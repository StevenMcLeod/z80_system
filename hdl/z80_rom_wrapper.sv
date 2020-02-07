module z80_rom_wrapper(
    input logic clk,
    input logic ena,
    input Z80MasterBus ibus,
    output Z80SlaveBus obus
);

assign obus.mwait = 1'b1;

logic[7:0] rom['hC] = {
    'h3E, 'h20, 'h32, 'h00, 'h80, 'h3C, 'hFE, 'h7F, 'h20, 'hF8, 'h18, 'hF4
};

always_ff @(posedge clk)
begin
    obus.dslave <= 8'h00;
    
    if(ena == 1'b1) begin
        if(ibus.addr < 'hC)
            obus.dslave <= rom[ibus.addr];
    end
end

//z80_rom_ip rom (
//    .clka(clk),
//    .addra(ibus.addr[14:0]),
//    .douta(obus.dslave)
//);

endmodule
