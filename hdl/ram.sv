module ram #(
    parameter ADDR_W,
    parameter DATA_W = 8
) (
    input logic                 clk,
    input logic                 ena,
    input logic                 rd,
    input logic                 wr,
    input logic[ADDR_W-1:0]     addr,
    input logic[DATA_W-1:0]     din,
    output logic[DATA_W-1:0]    dout
);

localparam TOTAL_ADDRS      = 2 ** ADDR_W;
localparam ADDR_MASK        = TOTAL_ADDRS - 1;

logic[DATA_W-1:0] mem[TOTAL_ADDRS];

logic[DATA_W-1:0] outreg;

assign dout = outreg;

`ifdef SIM_CLEAR_RAM
initial
begin
    for(int i = 0; i < TOTAL_ADDRS; ++i) begin
        mem[i] = '0;
    end
end
`endif

always_ff @(posedge clk)
begin
    if(ena == 1'b1) begin
        if(rd == 1'b1) begin
            outreg <= mem[addr];
        end

        if(wr == 1'b1) begin
            mem[addr] <= din;
        end
    end
end

endmodule : ram

