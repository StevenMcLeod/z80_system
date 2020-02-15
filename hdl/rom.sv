module rom #(
    parameter string FNAME,
    parameter ADDR_W,
    parameter DATA_W = 8
) (
    input logic                 clk,
    input logic                 ena,
    input logic[ADDR_W-1:0]     addr,
    output logic[DATA_W-1:0]    dout
);

localparam BYTES_PER_ADDR   = ((DATA_W - 1) / 8) + 1;
localparam TOTAL_ADDRS      = 2 ** ADDR_W;

logic[DATA_W-1:0] mem[TOTAL_ADDRS];

logic[DATA_W-1:0] outreg;

assign dout = outreg;

initial 
begin
    automatic integer romfile;

    if(DATA_W == 0)
        $fatal("Data width cannot be zero");

    romfile = $fopen(FNAME, "rb");
    if(romfile == 0)
        $fatal($sformatf("Couldn't open file %s!", FNAME));

    for(int addr = 0; addr < TOTAL_ADDRS; ++addr) begin
        for(int bp = 0; bp < BYTES_PER_ADDR; ++bp) begin
            automatic bit[8:0] c = $fgetc(romfile);
            if(c == 'h1FF)
                $fatal($sformatf("Rom File \"%s\" not large enough!", FNAME));

            mem[addr][bp*8 +: 8] = c[7:0];
        end
    end

    $fclose(romfile);
end

always_ff @(posedge clk)
begin
    if(ena == 1'b1) begin
        outreg <= mem[addr];
    end
end

endmodule : rom

