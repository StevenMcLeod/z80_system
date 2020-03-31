// SFX Ports:
// 7D00: Walk (analog)
// 7D01: Jump (analog)
// 7D02: Crash (analog)
// 7D03: Credit
// 7D04: Fall
// 7D05: Points

module dkong_sound (
    input logic masterclk,
    input logic soundclk,
    input logic rst_n,

    // CPU IO ports
    input logic vf2,
    input logic[3:0] bg_port,
    input logic[5:0] sfx_port,
    input logic audio_irq,
    output logic audio_ack,

    // Sound output ports
    output logic dac_mute,
    output logic[7:0] dac_out,
    output logic walk_out,      // 7D00
    output logic jump_out,      // 7D01
    output logic crash_out      // 7D02
);

logic xtal3;

logic[7:0] pb_in, pb_out;
logic rd_n,
      psen_n,
      ale;
logic[7:0] dmem_addr;
logic[7:0] dmem_din, dmem_dout;
logic      dmem_we;

logic data_rd_loc;
logic[7:0] coderom_data,
           datarom_data;

logic db_dir;
logic[7:0] din, dout;
logic[11:0] addr;

logic[23:0] lfsr;
logic lfsr_out, lfsr_out_d;
logic vf2_d;
logic[2:0] noise_cntr;
logic noise_out;

assign pb_in = {2'b11, sfx_port[3], 5'b11111};
assign dac_mute = pb_out[7];
assign data_rd_loc = pb_out[6];
assign audio_ack = ~pb_out[4];
assign addr[11:8] = pb_out[3:0];

assign walk_out = sfx_port[0];
assign jump_out = sfx_port[1];
assign crash_out = sfx_port[2];

// I8035
t48_core cpu (
    .xtal_i(soundclk),
    .xtal_en_i(1'b1),
    .reset_i(rst_n),        // RST_N

    .t0_i(sfx_port[5]),
    .t0_o(),
    .t0_dir_o(),

    .int_n_i(audio_irq),
    .ea_i(1'b1),
    .rd_n_o(rd_n),
    .psen_n_o(psen_n),
    .wr_n_o(),
    .ale_o(ale),
    
    .db_i(din),
    .db_o(dout),
    .db_dir_o(db_dir),

    .t1_i(sfx_port[4]),
    .p2_i(pb_in),
    .p2_o(pb_out),
    .p2l_low_imp_o(),
    .p2h_low_imp_o(),
    .p1_i(8'hFF),
    .p1_o(dac_out),
    .p1_low_imp_o(),
    .prog_n_o(),

    .clk_i(soundclk),       // Example in i8039_notri.vhd
    .en_clk_i(xtal3),
    .xtal3_o(xtal3),
    .dmem_addr_o(dmem_addr),
    .dmem_we_o(dmem_we),
    .dmem_data_i(dmem_din),
    .dmem_data_o(dmem_dout),
    .pmem_addr_o(),
    .pmem_data_i(8'hFF)
);

// Address latch
always_ff @(posedge soundclk)
begin
    if(ale) begin
        addr[7:0] <= dout;
    end
end

// Read driver
always_comb
begin
    din <= 8'h00;
    if(psen_n == 1'b0) begin
        din <= coderom_data;
    end else if(rd_n == 1'b0) begin
        if(data_rd_loc == 1'b0) begin
            din <= datarom_data;
        end else begin
            din <= {4'b0000, bg_port};
        end
    end
end

// I8035 internal RAM
ram#(6) i8035_int_ram (
    .clk(soundclk),
    .ena(1'b1),
    .rd(1'b1),
    .wr(dmem_we),
    .addr(dmem_addr),
    .din(dmem_dout),
    .dout(dmem_din)
);

// Code ROM
`ifdef SIMULATION
rom#("roms/sound/s_3i_b.bin", 11) rom_3h (
    .clk(soundclk),
    .ena(1'b1),
    .addr(addr),
    .dout(coderom_data)
);
`else
sou_3h_rom rom_3h (
    .clka(soundclk),
    .ena(1'b1),
    .addra(addr),
    .douta(coderom_data)
);
`endif

// Data ROM
`ifdef SIMULATION
rom#("roms/sound/s_3j_b.bin", 11) rom_3f (
    .clk(soundclk),
    .ena(1'b1),
    .addr(addr),
    .dout(datarom_data)
);
`else
sou_3f_rom rom_3f (
    .clka(soundclk),
    .ena(1'b1),
    .addra(addr),
    .douta(datarom_data)
);
`endif

// LFSR
assign lfsr_out = lfsr[23] ^ lfsr[10];
assign noise_out = noise_cntr[2];

always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0) begin
        lfsr <= 0;
        vf2_d <= 0;
        noise_cntr <= 0;
    end else if(vf2_d == 1'b0 && vf2 == 1'b1)  begin
        // Rising
        lfsr <= {lfsr[22:0], ~lfsr_out};

        if(lfsr_out_d == 1'b0 && lfsr_out == 1'b1) begin
            // Rising
            noise_cntr <= noise_cntr + 1;
        end
    end

    lfsr_out_d <= lfsr_out;
    vf2_d <= vf2;
end

endmodule : dkong_sound
