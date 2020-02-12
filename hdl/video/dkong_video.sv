module dkong_video (
    input logic clk,
    input logic rst_n,

    // Z80 Interface
    input Z80MasterBus ibus,
    output Z80SlaveBus obus,

    // Enables
    input logic tile_ena,
    input logic obj_ena,

    // VidCtrl Signals
    input logic grid_ena,   // 7D81h
    input logic flip_ena,   // 7D82h
    input logic psl2_ena,   // 7D83h
    input logic[1:0] cref,  // 7D86h - 7D87h

    // Processor Signal
    output logic vblank,
    output logic vram_busy,

    // Timing Signal
    output logic[9:0] htiming,
    output logic[7:0] vtiming,
    output logic cmpblk,

    // Video Signals
    output logic[2:0] r_sig,
    output logic[2:0] g_sig,
    output logic[1:0] b_sig
);

logic cmpblk2;

logic[3:0] tile_col, obj_col, mux_col;
logic[1:0] tile_vid, obj_vid, mux_vid;

// cmpblk2
always_ff @(posedge clk)
begin
    cmpblk2 <= cmpblk;
end


//
//    VSel  ----\
//               |
//              \v
//    Tile----->|\
//              | \
//              | |
//              | | --> Palette --> RGB[7:0]
//              | |
//              | /
//    Sprite--->|/
//              /
//

// Video Mux
always_comb
begin
    if(obj_vid == 2'b00) begin
        mux_col <= tile_col;
        mux_vid <= tile_vid;
    end else begin
        mux_col <= obj_col;
        mux_vid <= obj_vid;
    end
end

// Tile Generator
//tilegen tile ();
// For Testing, hardwire outputs
assign tile_col = 4'b0000;
assign tile_vid = 2'b00;

// Sprite Generator
// For Milestone 2, hardwire outputs
assign obj_col = 4'b0000;
assign obj_vid = 2'b00;

// Paletter
paletter pal (
    .clk(clk),
    .rst_n(rst_n),
    .h_half(htiming[0]),
    .cmpblk2(cmpblk2),

    .col(mux_col),
    .vid(mux_vid),
    .cref(cref),

    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig)
);

endmodule : dkong_video
