module paletter (
    input logic clk,
    input logic rst_n,

    input logic[2:0] phi,
    input logic h_half,
    input logic cmpblk2,

    input logic[1:0] game_type,

    input logic[3:0] col,
    input logic[1:0] vid,
    input logic[1:0] cref,

    output logic video_valid,
    output logic[2:0] r_sig,
    output logic[2:0] g_sig,
    output logic[1:0] b_sig
);

logic[7:0] palette_out;
logic[7:0] palette_addr;
logic cmpblk2_d;
logic do_clear;

assign palette_addr = {cref, col, vid};
assign do_clear = (cmpblk2 & cmpblk2_d);
assign video_valid = ~cmpblk2_d;
//assign video_valid = ~cmpblk2;

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        cmpblk2_d <= 1'b1;
    end else if(phi == 3 && h_half == 1'b0) begin   // TODO this should be clock enabled by 4H - 1/2H
        cmpblk2_d <= cmpblk2;
    end
end

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0 
    || do_clear == 1'b1) begin
        r_sig <= 3'b000;
        g_sig <= 3'b000;
        b_sig <= 3'b000;
    end else if(h_half == 1'b1) begin
        r_sig <= palette_out[7:5];
        g_sig <= palette_out[4:2];
        b_sig <= palette_out[1:0];
    end
end

// First 4 bit PROM
// Bit 1-0: G[1:0]
// Bit 3-2: B[1:0]
`ifdef SIMULATION
rom#("roms/palette/c-2k.bpr", 8, 4) prom_2e (
    .clk(clk),
    .ena(1'b1),
    .addr(palette_addr),
    .dout(palette_out[3:0])
);
`else
palette_2e_banked_prom prom_2e (
    .clka(clk),
    .ena(1'b1),
    .addra({game_type, palette_addr}),
    .douta(palette_out[3:0])
);
`endif

// Second 4 bit PROM
// Bit 0: G[2]
// Bit 3-1: R[2:0]
`ifdef SIMULATION
rom#("roms/palette/c-2j.bpr", 8, 4) prom_2f (
    .clk(clk),
    .ena(1'b1),
    .addr(palette_addr),
    .dout(palette_out[7:4])
);
`else
palette_2f_banked_prom prom_2f (
    .clka(clk),
    .ena(1'b1),
    .addra({game_type, palette_addr}),
    .douta(palette_out[7:4])
);
`endif

endmodule : paletter
