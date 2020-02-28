`include "../Z80Bus.vh"

module dkong_video (
    input logic clk,
    input logic rst_n,

    // Z80 Interface
    input Z80MasterBus ibus,
    output Z80SlaveBus tile_bus,
    output Z80SlaveBus obj_bus,

    // Enables
    input logic tile_ena,
    input logic obj_ena,

    // VidCtrl Signals
    input logic grid_ena,   // 7D81h
    input logic flip_ena,   // 7D82h
    input logic psl2_ena,   // 7D83h
    input logic[1:0] cref,  // 7D86h - 7D87h

    // Processor Signal
    output logic cpuclk,
    output logic vblk,
    output logic vram_busy,

    // Timing Signal
    output logic[9:0] htiming,
    output logic[8:0] vtiming,

    // Video Signals
    output logic video_valid,
    output logic[2:0] r_sig,
    output logic[2:0] g_sig,
    output logic[1:0] b_sig
);

// ECL Clock Gen
logic[2:0] phi;
logic phi_12, phi_34;

// Vert Gen
logic vclk;
logic[7:0] vtiming_f;
logic cmpblk, cmpblk2;

// Color Signals
logic[3:0] tile_col, obj_col, mux_col;
logic[1:0] tile_vid, obj_vid, mux_vid;

// Sprite Signals
logic attrib_cen;

// Wait Signals
assign tile_bus.mwait = ~vram_busy;
assign obj_bus.mwait = 1'b1;

// Clock Gen
// On original dkong board, master clock is 61.44MHz
// Goes through a 10136 (4 bit counter) that counts to 5.
//   - Clk phi_12 active cycles 0, 1. (12M, 40% duty)
//   - Clk phi_34 active cycles 2, 3. (12M, 40% duty)
// HTiming generated from ~phi_34.
// CPU operates on 1H clock (61.44 / 5 / 4 = 3.072)
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        phi <= 3'b000;
    end else begin
        if(phi == 3'b100) begin
            phi <= 3'b000;
        end else begin
            phi <= phi + 1;
        end
    end
end

assign phi_12 = ~(phi[1] | phi[2]);
assign phi_34 = phi[1];

// Horiz Gen
// H[0]: 1/2H
// H[1]: 1H
// H[2]: 2H
// H[3]: 4H
// H[4]: 8H
// H[5]: 16H
// H[6]: 32H
// H[7]: 64H
// H[8]: 128H
// H[9]: 256H

// Sgnl |   0 | 128 | 256 | 384 | 385 (0) (H Pulses, x2 for Clks)
// 128H | L>L | L>H | H>L |   L | L>L
// 256H | H>L |   L | L>H |   H | H>L
//   CA | H>L |   L |   L | L>H | H>L
always_ff @(posedge clk)
begin
    // Clked on ~phi_34, rising on phi == 4
    if(rst_n == 1'b0) begin
        htiming <= 0;
    end else if(phi == 3) begin
        if(htiming == 2*384 - 1) begin
            // Reset Horiz
            htiming <= 0;
        end else begin
            // Inc Horiz
            htiming <= htiming + 1;
        end
    end
end

// Cpuclk == 1H
assign cpuclk = htiming[1];

// Vert Gen
// V[0]: 1V
// V[1]: 2V
// V[2]: 4V
// V[3]: 8V
// V[4]: 16V
// V[5]: 32V
// V[6]: 64V
// V[7]: 128V
// V[8]: 256V (Counter internal)
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        vclk <= 1'b0;
        vtiming <= 9'b0111_1100_0;
    end else if(htiming[9] == 1'b0) begin
        vclk <= 1'b0;
    end else if(htiming[5] == 1'b1) begin  
        // Update vclk
        vclk <= htiming[6] & ~htiming[7];

        // Test for rising
        if(vclk == 1'b0 
        && (htiming[6] & ~htiming[7]) == 1'b1) begin
            if(vtiming == 9'b1111_1111_1) begin
                // Reset vtiming
                vtiming <= 9'b0111_1100_0;
            end else begin
                // Inc vtiming
                vtiming <= vtiming + 1;
            end
        end
    end
end

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        vblk <= 1'b0;
    end else if(vtiming[4] == 1'b1) begin   // Clked by 16V, Data static until next clk edge
        vblk <= &(vtiming[7:5]);            // 32V & 64V & 128V
    end
end

assign vtiming_f = vtiming[7:0] ^ {8{flip_ena}};

// cmpblk
assign cmpblk = vblk | htiming[9];

always_ff @(posedge clk)
begin
    // Clked by ~phi_34 -> rising on phi == 4
    if(rst_n == 1'b0) begin
        cmpblk2 <= 1'b1;
    end else if(phi == 3 && attrib_cen == 1'b1) begin
        cmpblk2 <= cmpblk;
    end
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
tilegen tile (
    .clk(clk),
    .rst_n(rst_n),
    
    .vtiming_f(vtiming_f),
    .htiming(htiming),
    .cmpblk(cmpblk),
    
    .flip_ena(flip_ena),

    .rdn(ibus.rdn),
    .wrn(ibus.wrn),
    .tile_ena(tile_ena),
    .addr(ibus.addr[9:0]),
    .din(ibus.dmaster),
    .dout(tile_bus.dslave),

    .es_blk(),
    .vram_busy(vram_busy),

    .tile_vid(tile_vid),
    .tile_col(tile_col)
);

// Sprite Generator
// For Milestone 2, hardwire outputs
spritegen sprite (
    .clk(clk),
    .rst_n(rst_n),
    
    .vtiming_f(vtiming_f),
    .htiming(htiming),
    .cmpblk2(cmpblk2),

    .flip_ena(flip_ena),
    .psl2_ena(psl_ena),

    .rdn(ibus.rdn),
    .wrn(ibus.wrn),
    .obj_ena(obj_ena),
    .addr(ibus.addr[9:0]),
    .din(ibus.dmaster),
    .dout(obj_bus.dslave),

    .obj_vid(obj_vid),
    .obj_col(obj_col)
);

// TEMPORARY UNTIL PAST MILESTONE 2
assign attrib_cen = ~|(htiming[3:0]);

// Paletter
paletter pal (
    .clk(clk),
    .rst_n(rst_n),
    .h_half(htiming[0]),
    .cmpblk2(cmpblk2),

    .col(mux_col),
    .vid(mux_vid),
    .cref(cref),

    .video_valid(video_valid),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig)
);

endmodule : dkong_video
