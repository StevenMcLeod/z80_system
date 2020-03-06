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
logic sprites_at_max, end_of_sprites_marker;
logic sprite_on_scanline, do_scratch_write, do_scratch_write_clk;
logic[7:0] scratch_load_addr;

// Scratchpad
logic[5:0] scratch_timing_addr, scratch_addr;
logic[8:0] scratch_din, scratch_dout;
logic scratch_wr, scratch_wr_d;

// Scratchpad -> Linebuffer
logic[7:0] sprite_flip_offset;
logic[7:0] sprite_vpos;
logic[6:0] sprite_index;
logic sprite_hflip_buf;
logic sprite_hflip;
logic sprite_vflip;
logic[3:0] sprite_palette;
logic[3:0] sprite_state, sprite_state_edge;
logic do_sprite_output;
logic stop_sprite_output;
logic do_sprite_load;

// Linebuffer
logic linebuf_flip, linebuf_hblkn;
logic linebuf_addr_clr, linebuf_addr_load;
logic linebuf_addr_clk;
logic[7:0] linebuf_addr, linebuf_addr_f;
logic[3:0] linebuf_col;
logic[1:0] linebuf_vid;
logic[5:0] linebuf_newdata;
logic[5:0] linebuf_din, linebuf_dout, linebuf_dout_buf;
logic linebuf_wr;

// Objrom
logic[10:0] objrom_index;
logic[15:0] objrom_out[2];
logic[15:0] objrom_buf[2];
logic[3:0]  obj_pixel;
logic[3:0]  obj_scanline;

// Combinational Assignments
assign objram_timing_addr = {psl2_ena, htiming[8:0]};
assign objram_wr = ~wrn & obj_ena;
assign objram_din = din;
assign dout = objram_dout;


// VAddr Mux
always_comb
begin
    if(obj_ena && (~rdn | ~wrn | ~rqn)) begin
        objram_addr <= addr;
        objram_ena <= ~rdn | ~wrn;
    end else begin
        objram_addr <= objram_timing_addr;
        objram_ena <= 1'b1;
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
    .addr(linebuf_addr_f),
    .din(linebuf_din),
    .dout(linebuf_dout)
);

// Sprite ROMs 7C, 7D
`ifdef SIMULATION
rom#("roms/sprite/l_4m_b.bin", 11) rom_7c (
    .clk(clk),
    .ena(htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[0][15:8])
);
`else
obj_7c_rom rom_7c (
    .clka(clk),
    .ena(htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[0][15:8])
);
`endif

`ifdef SIMULATION
rom#("roms/sprite/l_4n_b.bin", 11) rom_7d (
    .clk(clk),
    .ena(htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[0][7:0])
);
`else
obj_7d_rom rom_7d (
    .clka(clk),
    .ena(htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[0][7:0])
);
`endif

// Sprite ROMs 7E, 7F
`ifdef SIMULATION
rom#("roms/sprite/l_4r_b.bin", 11) rom_7e (
    .clk(clk),
    .ena(htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[1][15:8])
);
`else
obj_7e_rom rom_7e (
    .clka(clk),
    .ena(htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[1][15:8])
);
`endif

`ifdef SIMULATION
rom#("roms/sprite/l_4s_b.bin", 11) rom_7f (
    .clk(clk),
    .ena(htiming[9]),
    .addr(objrom_index),
    .dout(objrom_out[1][7:0])
);
`else
obj_7f_rom rom_7f (
    .clka(clk),
    .ena(htiming[9]),
    .addra(objrom_index),
    .douta(objrom_out[1][7:0])
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
// TODO: Last end_of_sprites_marker cut off, could impact sprites at 0x1FF
always_ff @(posedge clk)
begin
    // Clocked on falling phi_34 -> phi == 2
    if(phi == 1) begin
        objram_buf <= objram_dout;
        scratch_din[7:0] <= objram_buf;
    end
end

assign scratch_din[8] = end_of_sprites_marker;

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
assign sprites_at_max = |(scratch_load_addr[7:6]);
assign end_of_sprites_marker = &(htiming[8:2]) & ~sprites_at_max;
assign scratch_wr = (phi == 2)      // Clocked on rising phi_34 -> phi == 2
                 && (htiming[9] == 1'b0) 
                 && do_scratch_write 
                 && ~sprites_at_max;

always_comb
begin
    if(htiming[9] == 1'b0) begin
        scratch_addr <= scratch_load_addr;
    end else begin
        scratch_addr <= scratch_timing_addr;
    end
end

assign do_scratch_write_clk = (htiming[1:0] == 2'b01) && phi == 4;

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0 || htiming[9] == 1'b1) begin
        do_scratch_write <= 1'b0;
    end else if(do_scratch_write_clk) begin 
        do_scratch_write <= sprite_on_scanline | end_of_sprites_marker;
    end
end

// Part 2: scratchpad -> linebuffer

// VFC Timing
always_ff @(posedge clk)
begin
    if(htiming[9] == 1'b0)
        vtiming_fc <= vtiming_f;
end

// Sprite State Machine
//  0 - Load VPos
//  1 - Load Index
//  2 - Load Attrib
//  3 - Load HPos
always_comb
begin
    logic[1:0] state_no;

    state_no = htiming[3:2];
    sprite_state <= 4'b0000;
    sprite_state_edge <= 4'b0000;

    sprite_state[state_no] <= 1'b1;
    if(phi == 3 && htiming[1:0] == 2'b11) begin     // One phi before transition
        sprite_state_edge[state_no] <= 1'b1;
    end
end

assign flip_ena_gated = flip_ena & sprite_state[0];

always_comb
begin
    if(flip_ena_gated == 1'b0)
        sprite_flip_offset <= scratch_dout[7:0] + SPRITE_ADD_F0;
    else
        sprite_flip_offset <= scratch_dout[7:0] + SPRITE_ADD_F1;
end

// Load VPos
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        sprite_vpos <= 0;
    end else if(sprite_state_edge[0]) begin
        sprite_vpos <= sprite_flip_offset + vtiming_fc;
    end
end

assign do_sprite_output = &(sprite_vpos[7:4]);

// Load Index
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        sprite_vflip <= 0;
        sprite_index <= 0;
    end else if(sprite_state[1]) begin
        sprite_vflip <= scratch_dout[7];
        sprite_index <= scratch_dout[6:0];
    end
end

// Load Attrib
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        sprite_hflip <= 0;
        sprite_palette <= 0;
    end else if(sprite_state_edge[2]) begin
        sprite_hflip <= scratch_dout[7];
        sprite_palette <= scratch_dout[3:0];
    end
end

// Buffered Signals
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        sprite_hflip_buf <= 0;
        linebuf_hblkn <= 0;
        linebuf_flip <= 0;
        linebuf_col <= 0;
    end else if(phi == 3 && htiming[3:0] == 4'b1111) begin
        sprite_hflip_buf <= sprite_hflip;
        linebuf_hblkn <= ~htiming[9];
        linebuf_flip <= flip_ena & ~htiming[9];
        linebuf_col <= sprite_palette;
    end
end

// JKFF 8N
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0 || htiming[9] == 1'b0) begin
        stop_sprite_output <= 1'b0;
    end else if(sprite_state_edge[0]) begin
        if(scratch_dout[8] == 1'b1)
            stop_sprite_output <= 1'b1;
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
// When do_spr_out & ~stop_spr_out & ~&[4H:1/2H] == 1
//      VFlip == 0 -> Mode == 11, Load.
//      VFlip == 1 -> Mode == 11, Load.
//      Load step in sprite, lasts 1 pix
//
// When ~do_spr_out | stop_spr_out | &[4H:1/2H] == 0
//      VFlip == 0 -> Mode == 10, Left.
//      VFlip == 1 -> Mode == 01, Right.
//      Shift step in sprite, lasts 15 pix
//      On stop_spr_out, all bits will be 0s
assign do_sprite_load = do_sprite_output
                      & ~stop_sprite_output 
                      & &(htiming[3:0]);

always_ff @(posedge clk)
begin
    if(phi == 3) begin // Clocked on rising ~phi_34
        if(do_sprite_load) begin
            // Load new sprite
            for(int i = 0; i < $size(objrom_buf); ++i) begin
                objrom_buf[i] <= objrom_out[i];
            end
        end else begin
            // Simulate shift reg 
            // if no new sprite loaded dont print any pixels
            for(int i = 0; i < $size(objrom_buf); ++i) begin
                objrom_buf[i][obj_pixel] <= 1'b0;
            end
        end
    end
end

assign obj_scanline = sprite_vpos[3:0] ^ {4{sprite_vflip}};
assign objrom_index = {sprite_index, obj_scanline};
assign obj_pixel = ~(htiming[3:0] ^ {4{sprite_hflip_buf}});

always_comb
begin
    for(int i = 0; i < $size(objrom_buf); ++i) begin
        linebuf_vid[i] <= objrom_buf[i][obj_pixel];
    end
end

// Part 3: linebuffer -> vidmux

// Linebuf din mux
always_comb
begin
    if(linebuf_hblkn == 1'b1) begin
        linebuf_din <= 6'b000000;
    end else if(linebuf_newdata[1:0] != 2'b00) begin
        linebuf_din <= linebuf_newdata;
    end else begin
        linebuf_din <= linebuf_dout;
    end
end

assign linebuf_addr_clk = (phi == 3)
                       && (htiming[0] | ~linebuf_hblkn); 

// Linebuffer State Machine
//always_comb
//begin
//    logic[1:0] to_decode;
//    
//    linebuf_addr_clr <= 1'b0;
//    linebuf_addr_load <= 1'b0;
//
//    to_decode = {~htiming[9], htiming[3]};
//    if(new_sprite_clk == 1'b0) begin
//        // Nothing
//    end else if(to_decode == 2'b01) begin
//        linebuf_addr_load <= 1'b1;
//    end else if(to_decode == 2'b11) begin
//        linebuf_addr_clr <= ~linebuf_hblkn; 
//    end
//end
always_comb
begin
    linebuf_addr_clr <= 1'b0;
    linebuf_addr_load <= 1'b0;

    if(&(htiming[3:0]) == 1'b1) begin
        if(htiming[9] == 1'b1) begin
            linebuf_addr_load <= 1'b1;
        end else begin
            linebuf_addr_clr <= ~linebuf_hblkn;
        end
    end
end


always_ff @(posedge clk) begin
    if(rst_n == 1'b0) begin
        linebuf_addr <= 0;
    end else if(linebuf_addr_clk == 1'b1) begin         // Do inc on falling
        if(linebuf_addr_clr == 1'b1) begin              // Synchronous Clear
            linebuf_addr <= 0;
        end else if(linebuf_addr_load == 1'b1) begin    // Load new hpos
            linebuf_addr <= sprite_flip_offset;
        end else begin                                  // Increment current hpos
            linebuf_addr <= linebuf_addr + 1;
        end
    end
end

always_ff @(posedge clk) begin
    if(rst_n == 1'b0) begin
        linebuf_dout_buf <= 0;
    end else if(phi == 0) begin     // Rising phi_12
        linebuf_dout_buf <= linebuf_dout;
    end
end

assign linebuf_addr_f = linebuf_addr ^ {8{linebuf_flip}};
assign linebuf_wr = linebuf_addr_clk;

assign obj_col = linebuf_dout_buf[5:2];
assign obj_vid = linebuf_dout_buf[1:0];
assign linebuf_newdata = {linebuf_col, linebuf_vid};

endmodule : spritegen
