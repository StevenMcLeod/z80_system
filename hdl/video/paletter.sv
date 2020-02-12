module paletter (
    input logic clk,
    input logic rst_n,
    input logic h_half,
    input logic cmpblk2,

    input logic[3:0] col,
    input logic[1:0] vid,
    input logic[1:0] cref,

    output logic[2:0] r_sig,
    output logic[2:0] g_sig,
    output logic[1:0] b_sig
);

logic work_done;
logic[7:0] palette_out;
logic[7:0] palette_addr;

assign palette_addr = {cref, col, vid};

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        work_done <= 1'b0;
    end

    if(cmpblk2 == 1'b1) begin
        r_sig <= 3'b000;
        g_sig <= 3'b000;
        b_sig <= 3'b000;
    end else if(h_half == 1'b1) begin
        if(work_done == 1'b0) begin
            r_sig <= palette_out[2:0];
            g_sig <= palette_out[5:3];
            b_sig <= palette_out[7:6];
        end
        
        work_done <= 1'b1;
    end else if(h_half == 1'b0) begin
        work_done <= 1'b0;
    end
end

// First 4 bit PROM
// Bit 0: G[2]
// Bit 3-1: R[2:0]
plainrom#("c-2j.bpr", 8, 4) prom_2f (
    .clk(clk),
    .ena(1'b1),
    .addr(palette_addr),
    .dout(palette_out[3:0])
);

// second 4 bit PROM
// Bit 1-0: G[1:0]
// Bit 3-2: B[1:0]
plainrom#("c-2k.bpr", 8, 4) prom_2e (
    .clk(clk),
    .ena(1'b1),
    .addr(palette_addr),
    .dout(palette_out[7:4])
);

endmodule : paletter
