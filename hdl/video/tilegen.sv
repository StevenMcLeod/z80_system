module tilegen (
    input logic clk,
    input logic rst_n,

    // Timing Signals
    input logic[7:0] vtiming_f,
    input logic[9:0] htiming,
    input logic cmpblk,

    // Vidctrl Signals
    input logic flip_ena,

    // CPU Signals
    input logic rdn, wrn,
    input logic tile_ena,
    input logic[9:0] addr,
    input logic[7:0] din,
    output logic[7:0] dout,

    output logic es_blk,
    output logic vram_busy,

    // Output Signals
    output logic[1:0] tile_vid,
    output logic[3:0] tile_col
);

// Timing
logic[9:0] htiming_f;
logic[2:0] tile_scanline;

// Tileram
logic[9:0] timing_addr, tileram_addr;
logic[7:0] tileram_din, tileram_dout;
logic tileram_ena, tileram_wr;

// Tilerom access
logic[10:0] tilerom_index;
logic[7:0] tilerom_out[2];
logic[7:0] tilerom_buf[2];
logic[2:0] tile_pixel;

// Colourrom
logic[3:0] col_out;

assign htiming_f = htiming ^ {10{flip_ena}};
assign tile_scanline = vtiming_f[2:0];

assign timing_addr = {vtiming_f[7:3], htiming_f[8:4]};

assign tilerom_index = {tileram_dout, tile_scanline};

assign tileram_wr = ~wrn & tile_ena;
assign tileram_din = din;
assign dout = tileram_dout;

// VAddr Mux
always_comb
begin
    if(cmpblk == 1'b0) begin
        tileram_addr <= timing_addr;
        tileram_ena <= 1'b1;
    end else begin
        tileram_addr <= addr;
        tileram_ena <= ~rdn | ~wrn;
    end
end

// Visible area 7440h - 77BFh
// Tileram 2P, 2R
ram#(10) tileram (
    .clk(clk),
    .ena(tileram_ena),
    .rd(1'b1),
    .wr(tileram_wr),
    .addr(tileram_addr),
    .din(tileram_din),
    .dout(tileram_dout)
);

// Vert Colour Decoder 5E
`ifdef SIMULATION
rom#("roms/tile/v-5e.bpr", 8, 4) prom_2n (
    .clk(clk),
    .ena(1'b1),
    .addr({tileram_addr[9:7], tileram_addr[4:0]}),
    .dout(col_out)
);
`else
tile_2n_prom prom_2n (
    .clka(clk),
    .ena(1'b1),
    .addra({tileram_addr[9:7], tileram_addr[4:0]}),
    .douta(col_out)
);
`endif

// Tilerom 3P
`ifdef SIMULATION
rom#("roms/tile/v_3pt.bin", 11) rom_3p (
    .clk(clk),
    .ena(~htiming[9]),
    .addr(tilerom_index),
    .dout(tilerom_out[0])
);
`else
tile_3p_rom rom_3p (
    .clka(clk),
    .ena(~htiming[9]),
    .addra(tilerom_index),
    .douta(tilerom_out[0])
);
`endif

// Tilerom 3N
`ifdef SIMULATION
rom#("roms/tile/v_5h_b.bin", 11) rom_3n (
    .clk(clk),
    .ena(~htiming[9]),
    .addr(tilerom_index),
    .dout(tilerom_out[1])
);
`else
tile_3n_rom rom_3n (
    .clka(clk),
    .ena(~htiming[9]),
    .addra(tilerom_index),
    .douta(tilerom_out[1])
);
`endif

// Tile Col Reg
always_ff @(posedge clk)
begin
    if(htiming[3:1] == 3'b000) begin
        tile_col <= col_out;
    end
end

// Tile shifter
// Uses 74LS299 for left/right shifting
// Shifter modes:
//   00 - Hold
//   01 - Right
//   10 - Left
//   11 - Load
//
// When tileram_addr == timing_addr,
//      5E strobed high by NAND 4H (on 4H:1H = 7)
//      Flip == 0 -> Mode == {1, 5E}, Load/Left.
//      Flip == 1 -> Mode == {5E, 1}, Load/Right.
//
// When tileram_addr == cpu_addr,
//      5E always 0
//      Flip == 0 -> Mode == 10, Left.
//      Flip == 1 -> Mode == 01, Right.
//      Doesn't matter as video cleared by cmpblk2
always_ff @(posedge clk)
begin
    if(htiming[0] == 1'b0) begin
        if(htiming[3:1] == 3'b000) begin
            // Load new tile
            for(int i = 0; i < $size(tilerom_buf); ++i) begin
                tilerom_buf[i] <= tilerom_out[i];
            end
        end
    end
end

assign tile_pixel = ~htiming_f[3:1];

always_comb
begin
    for(int i = 0; i < $size(tilerom_buf); ++i) begin
        tile_vid[i] <= tilerom_buf[i][tile_pixel];
    end
end

// VRAM_BUSY and ES_BLK
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        vram_busy <= 1'b0;
    end else if(htiming[9] == 1'b0) begin   // In active video
        vram_busy <= 1'b1;
    end else if(htiming[2] == 1'b1) begin   // Test if in HBLK
        vram_busy <= &(htiming[7:4]);
    end
end

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        es_blk <= 1'b0;
    end else if(htiming[9] == 1'b0) begin
        es_blk <= 1'b0;
    end else if(htiming[6] == 1'b1) begin
        es_blk <= ~htiming[7];
    end
end

endmodule : tilegen
