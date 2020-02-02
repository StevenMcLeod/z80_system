`include "Z80Bus.vh"

module rom #(
    parameter string FNAME,
    parameter ADDR_W,
    parameter DATA_W = 8
) (
    input logic         clk,
    input logic         ena,
    input Z80MasterBus  ibus,
    output Z80SlaveBus  obus
);

localparam BYTES_PER_ADDR   = ((DATA_W - 1) / 8) + 1;
localparam TOTAL_ADDRS      = 2 ** ADDR_W;
localparam ADDR_MASK        = TOTAL_ADDRS - 1;

logic[DATA_W-1:0] mem[TOTAL_ADDRS];
// = {
//    8'h3E, 8'h20, 8'h32, 8'h00,
//    8'h80, 8'h3C, 8'hFE, 8'h7F,
//    8'h20, 8'hF8, 8'h18, 8'hF4
//};


logic[DATA_W-1:0] outreg;

assign obus.dslave = outreg;
assign obus.mwait = 1'b1;

initial 
begin
    integer romfile;

    if(DATA_W == 0)
        $fatal("Data width cannot be zero");

    romfile = $fopen(FNAME, "r");
    if(romfile == 0)
        $fatal($sformatf("Couldn't open file %s!", FNAME));

    for(int addr = 0; addr < TOTAL_ADDRS; ++addr) begin
        for(int bp = 0; bp < BYTES_PER_ADDR; ++bp) begin
            mem[addr][bp*8 +: 8] = $fgetc(romfile);
        end
    end

    $fclose(romfile);
end

always_ff @(posedge clk)
begin
    if(ena) begin
        outreg <= mem[ibus.addr & ADDR_MASK];
    end
end

endmodule : rom
