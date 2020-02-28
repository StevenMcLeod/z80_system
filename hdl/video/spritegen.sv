module spritegen (
    input logic clk,
    input logic rst_n,

    // Timing Signals
    input logic[2:0] phi,
    input logic[7:0] vtiming_f,
    input logic[9:0] htiming,
    input logic cmpblk2,

    // Vidctrl Signals
    input logic flip_ena,
    input logic psl2_ena,

    // CPU Signals
    input logic rdn, wrn, rqn,
    input logic obj_ena,
    input logic[9:0] addr,
    input logic[7:0] din,
    output logic[7:0] dout,

    // Output Signals
    output logic[1:0] obj_vid,
    output logic[3:0] obj_col
);

assign obj_col = 4'b0000;
assign obj_vid = 2'b00;

// Sprite Add Constant
localparam SPRITE_ADD_F0 = 8'b1111_1000;    // -8
localparam SPRITE_ADD_F1 = 8'b1111_1010;    // -6

// Timing
logic[7:0] vtiming_fc;

// Vidctrl Derived
logic flip_ena_gated;

// Objram
logic[9:0] objram_timing_addr, objram_addr;
logic[7:0] objram_din, objram_dout;
logic objram_ena, objram_wr;

// Objram -> Scratch
logic[7:0] objram_buf;
logic sprite_on_scanline, do_scratch_write;
logic[7:0] scratch_load_addr;
logic scratch_at_max;

// Scratchpad
logic[5:0] scratch_timing_addr, scratch_addr;
logic[8:0] scratch_din, scratch_dout;
logic scratch_wr, scratch_wr_d;

// Scratchpad -> Linebuffer
logic sprite_flip_offset;
logic[7:0] sprite_hpos;
logic[7:0] sprite_vpos;
logic[6:0] sprite_index;
logic sprite_hflip;
logic sprite_vflip;
logic sprite_palette;
logic[1:0] sprite_state_machine;

// Linebuffer
logic[7:0] linebuf_addr, linebuf_addr_f;
logic[5:0] linebuf_newdata;
logic[5:0] linebuf_din, linebuf_dout;
logic linebuf_wr;

// Objrom
logic[11:0] objrom_index;
logic[15:0] objrom_out[2];
logic[15:0] objrom_buf[2];
logic[3:0]  obj_pixel;

// Combinational Assignments
assign linebuf_addr_f = linebuf_addr ^ {8{flip_ena}};
assign obj_scanline = 0;
assign objrom_index = 0;

assign objram_timing_addr = {psl2_ena, htiming[8:0]};
assign objram_wr = ~wrn & ~obj_ena;
assign objram_din = din;
assign dout = objram_dout;


// VAddr Mux
always_comb
begin
    if((~rdn | ~wrn | ~rqn) == 1'b0) begin
        objram_addr <= objram_timing_addr;
        objram_ena <= 1'b1;
    end else begin
        objram_addr <= addr;
        objram_ena <= ~rdn | ~wrn;
    end
end

// Bank switched by PSL2
// Objram 6P, 6R
ram#(10) objram (
    .clk(clk),
    .ena(objram_ena),
    .rd(1'b1),
    .wr(objram_wr),
    .addr(objram_addr),
    .din(objram_din),
    .dout(objram_dout)
);

// Sprite Scratchpad 7H
ram#(6, 9) scratchpad (
    .clk(clk),
    .ena(1'b1),
    .rd(1'b1),
    .wr(scratch_wr),
    .addr(scratch_addr),
    .din(scratch_din),
    .dout(scratch_dout)
);

// Linebuffer RAM 2E, 2H
ram#(8, 6) linebuffer (
    .clk(clk),
    .ena(1'b1),
    .rd(1'b1),
    .wr(linebuf_wr),
    .addr(linebuf_addr),
    .din(linebuf_din),
    .dout(linebuf_dout)
);

// Sprite ROMs 7C, 7D
`ifdef SIMULATION
rom#("roms/sprite/l-4m_b.bin") rom_7c (
    .clk(clk),
    .ena(~htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[1][15:8])
);
`else
obj_7c_rom rom_7c (
    .clka(clk),
    .ena(~htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[1][15:8])
);
`endif

`ifdef SIMULATION
rom#("roms/sprite/l-4n_b.bin") rom_7d (
    .clk(clk),
    .ena(~htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[1][7:0])
);
`else
obj_7d_rom rom_7d (
    .clka(clk),
    .ena(~htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[1][7:0])
);
`endif

// Sprite ROMs 7E, 7F
`ifdef SIMULATION
rom#("roms/sprite/l-4r_b.bin") rom_7e (
    .clk(clk),
    .ena(~htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[0][15:8])
);
`else
obj_7e_rom rom_7e (
    .clka(clk),
    .ena(~htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[0][15:8])
);
`endif

`ifdef SIMULATION
rom#("roms/sprite/l-4s_b.bin") rom_7f (
    .clk(clk),
    .ena(~htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[0][7:0])
);
`else
obj_7f_rom rom_7f (
    .clka(clk),
    .ena(~htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[0][7:0])
);
`endif

// Sprites are generated in two parts:
// Part 1: During Active Video, objram is scanned for sprites
//      active during the next scanline.
// Part 2: During HBlank, active sprites are pixmapped into a linebuffer.
// Part 3: During Active Video, pixels are read in order from 
//      linebuffer to produce output.
//

// Part 1: objram -> scratchpad logic
always_ff @(posedge clk)
begin
    // Clocked on falling phi_12 -> phi == 2
    if(phi == 2) begin
        objram_buf <= objram_dout;
        scratch_din[8:1] <= objram_buf;
    end
end

assign scratch_din[0] = scratch_at_max;

always_comb
begin
    logic[7:0] flip_added;
    logic[7:0] vf_added;

    if(flip_ena == 1'b0)
        flip_added = objram_buf + SPRITE_ADD_F0;
    else
        flip_added = objram_buf + SPRITE_ADD_F1;

    vf_added = flip_added + vtiming_f;
    sprite_on_scanline <= &(vf_added[7:4]);
end

always_ff @(posedge clk)
begin
    scratch_wr_d <= scratch_wr;
    
    if(rst_n == 1'b0 || htiming[9] == 1'b1) begin
        scratch_load_addr <= 0;
    end else if(scratch_wr_d == 1'b0 && scratch_wr == 1'b1) begin
        scratch_load_addr <= scratch_load_addr + 1;
    end
end

assign scratch_timing_addr = htiming[7:2];
assign scratch_wr = (phi == 0) 
                 && (htiming[9] == 1'b1) 
                 && do_scratch_write 
                 && ~|(scratch_load_addr[7:6]);
assign scratch_at_max = &(htiming[8:2]) & ~|(scratch_load_addr[7:6]);

always_comb
begin
    if(htiming[9] == 1'b0) begin
        scratch_addr <= scratch_load_addr;
    end else begin
        scratch_addr <= scratch_timing_addr;
    end
end

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0 || htiming == 1'b1) begin
        do_scratch_write <= 1'b0;
    end else if(htiming[1:0] == 2'b01) begin // TODO does this need to be only rising
        do_scratch_write <= sprite_on_scanline | scratch_at_max;
    end
end

// Part 2: scratchpad -> linebuffer

// VFC Timing
always_ff @(posedge clk)
begin
    if(htiming[9] == 1'b0)
        vtiming_fc <= vtiming_f;    // TODO does this need to be only rising
end

// Sprite State Machine
//  0 - Load VPos
//  1 - Load Index
//  2 - Load Attrib
//  3 - Load HPos
assign sprite_state_machine = htiming[3:2];

assign flip_ena_gated = flip_ena & (sprite_state_machine == 0);

always_comb
begin
    if(flip_ena_gated == 1'b0)
        sprite_flip_offset <= scratch_dout[8:1] + SPRITE_ADD_F0;
    else
        sprite_flip_offset <= scratch_dout[8:1] + SPRITE_ADD_F1;
end

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        sprite_vpos <= 0;
    end else if(sprite_state_machine == 0) begin
        sprite_vpos <= sprite_flip_offset + vtiming_fc;
    end
end

// Sprite shifter
// Uses 74LS299 for left/right shifting
// Shifter modes:
//   00 - Hold
//   01 - Right
//   10 - Left
//   11 - Load
//
// When , 
//      2J strobed high by NAND 2L (on 4H:1H = 7)
//      VFlip == 0 -> Mode == {1, 5E}, Load/Left.
//      VFlip == 1 -> Mode == {5E, 1}, Load/Right.
//
// When ,
//      2J always 0
//      VFlip == 0 -> Mode == 10, Left.
//      VFlip == 1 -> Mode == 01, Right.
//      Doesn't matter as video cleared by cmpblk2
always_ff @(posedge clk)
begin
    if(phi == 3) begin // Clocked on rising ~phi_34
        if(SHIFT_COND) begin
            // Load new sprite
            for(int i = 0; i < $size(objrom_buf); ++i) begin
                objrom_buf[i] <= objrom_out[i];
            end
        end
    end
end

assign obj_pixel = sprite_vpos[3:0] ^ {4{sprite_hflip}};

always_comb
begin
    for(int i = 0; i < $size(tilerom_buf); ++i) begin
        linebuf_newdata[i][1:0] <= tilerom_buf[i][tile_pixel];
    end
end



endmodule : spritegen
