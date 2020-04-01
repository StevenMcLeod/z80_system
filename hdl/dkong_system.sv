`define ARM_LOADER
`include "Z80Bus.vh"

module dkong_system #(
    parameter CLKS_PER_BIT = 1,
    parameter DEBUG_WAIT_ENA = 0,
    parameter IN0_ENA = 0,
    parameter IN1_ENA = 0,
    parameter IN2_ENA = 0
)(
    input logic masterclk,
    input logic soundclk,
    input logic rst_n,

    // UART signals
    input logic ser_in,
    output logic ser_out,

    // Video Signals
    output logic pixelclk,
    output logic video_valid,
    output logic[2:0] r_sig,
    output logic[2:0] g_sig,
    output logic[1:0] b_sig,

    // Sound Signals
    output logic dac_mute,
    output logic[7:0] dac_out,
    output logic walk_out,
    output logic jump_out,
    output logic crash_out,
    
    // Controls Signals
    input logic p1_r,
    input logic p1_l,
    input logic p1_u,
    input logic p1_d,
    input logic p1_b1,

    input logic p2_r,
    input logic p2_l,
    input logic p2_u,
    input logic p2_d,
    input logic p2_b1,

    input logic p1_sw,
    input logic p2_sw,
    input logic coin_sw,

    // Loader Signals
    input logic clkprogrom,
    input logic enprogrom,
    input logic weprogrom,
    input logic[13:0] addrprogrom,
    input logic[7:0] dinprogrom,
    output logic[7:0] doutprogrom,

    // Debug signals
    input logic debug_wait,
    output logic[7:0] debug_ahi,
    output logic[7:0] debug_alo,
    output logic[7:0] debug_dmaster,
    output logic[7:0] debug_dslave,
    output logic[7:0] debug_cpu_sig,
    output logic[7:0] debug_enables,
    output logic[7:0] debug_misc
);

localparam MASTER_QTY = 2;
localparam SLAVE_QTY = 7;

/*
 *  SIGNALS
 *
 */

logic cpuclk, cpuclk_d;
logic cpu_clk_rise, cpu_clk_fall;

// CPU signals
logic cpu_mreq,
      cpu_iorq,
      cpu_rd,
      cpu_wr,
      cpu_m1;

logic cpu_wait,
      cpu_wait_d,
      cpu_wait_p;

logic cpu_nmi,
      cpu_busrq_inv, cpu_busrq;

logic cpu_busack,
      cpu_halt,
      cpu_rfsh;

// Input Ports
logic[7:0] in0, in1, in2, dsw0;

// Output Ports
logic[3:0] bgm_port;
logic[5:0] sfx_port;
logic audio_ack;

logic audio_irq,
      grid_ena,
      flip_ena,
      psl2_ena,
      nmi_mask,
      dma_rdy;
logic[1:0] cref;


// Video Signals
logic vblk, vblk_d;
logic[7:0] vtiming;
      
// Bus Master Structs
Z80MasterBus cpu_bus,
             dma_master_bus;
Z80SlaveBus  master_shared_slave_bus;

// Bus Slave Structs
Z80SlaveBus  rom_bus,                   // 0000h - 3FFFh
             ram_bus,                   // 6000h - 6BFFh
             obj_bus,                   // 7000h - 73FFh
             tile_bus,                  // 7400h - 77FFh
             dma_slave_bus,             // 7800h - 780Fh
             io_bus,                    // 7C00h - 7DFFh
             oport_bus;                 // 7F00h - 7F00h
            
Z80MasterBus slave_shared_master_bus;

// Bus Signals
logic[$clog2(SLAVE_QTY)-1:0] bus_sel;

// Slave enables
logic rom_ena,
      ram_ena,
      obj_ena,
      tile_ena,
      dma_ena,
      io_ena,
      oport_ena;
      
// DEBUG Assigns
assign debug_ahi = slave_shared_master_bus.addr[15:8];
assign debug_alo = slave_shared_master_bus.addr[7:0];
assign debug_dmaster = slave_shared_master_bus.dmaster;
assign debug_dslave = master_shared_slave_bus.dslave;
assign debug_cpu_sig = {~cpu_nmi, ~cpu_busrq, ~master_shared_slave_bus.mwait, ~cpu_m1, ~cpu_iorq, ~cpu_mreq, ~cpu_wr, ~cpu_rd};
assign debug_enables = {oport_ena, io_ena, 1'b0, dma_ena, tile_ena, obj_ena, ram_ena, rom_ena};
assign debug_misc = {
    ~rst_n,
    6'b000000,
    slave_shared_master_bus.addr == 'h0066
};
                        
      
// Z80 Core
tv80s mycpu (
    .reset_n(rst_n),
    //.clk(masterclk),
    //.cen(cpu_clk_rise),
    .clk(cpuclk),
    .cen(1'b1),
    
    .wait_n(cpu_wait),
    //.wait_n(1'b0),
    .int_n(1'b1),
    .nmi_n(cpu_nmi),
    .busrq_n(cpu_busrq),
    
    .m1_n(cpu_m1),
    .mreq_n(cpu_mreq),
    .iorq_n(cpu_iorq),
    .rd_n(cpu_rd),
    .wr_n(cpu_wr),
    .rfsh_n(cpu_rfsh),
    .halt_n(cpu_halt),
    .busak_n(cpu_busack),

    .A(cpu_bus.addr),
    .di(master_shared_slave_bus.dslave),
    .dout(cpu_bus.dmaster)
);

assign cpu_bus.rdn = cpu_rd;
assign cpu_bus.wrn = cpu_wr;
assign cpu_bus.mreqn = cpu_mreq;
assign cpu_bus.iorqn = cpu_iorq;
assign cpu_busrq = ~cpu_busrq_inv;

// Clock enable
always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0)
        cpuclk_d <= cpuclk;
    else
        cpuclk_d <= cpuclk;
end

assign cpu_clk_rise = cpuclk & ~cpuclk_d;
assign cpu_clk_fall = ~cpuclk & cpuclk_d;

// NMI generator
always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0)
        cpu_nmi <= 1'b1;
    else if(nmi_mask == 1'b0)
        cpu_nmi <= 1'b1;
    else if(vblk_d == 1'b0 && vblk == 1'b1)   // Vblk rising
        cpu_nmi <= 1'b0;
end

always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0)
        vblk_d <= 1'b0;
    else
        vblk_d <= vblk;
end

// Wait Signal Generator
// On TV80 Core, cpu_mreq is asserted T2 rising instead of T1 falling. 
// Ignore cpu_mreq as io bus not used anyways.
assign cpu_wait_p = (cpu_bus.addr[15:10] == 6'b0111_01) 
                  //& ~cpu_mreq
                  & ~tile_bus.mwait;

// In TKG-4 board, this sequence occurs when writing to VRAM during VRAM_BUSY:
//          |  T 1  |  T 2  |  T W  |
//   CPUCLK /---\___/---\___/---\___/
//   ADDR   < mem: vram             >
//   ~WR    ------------\____________
//   ~VRAMR ------------~------------
//   WAIT_P \________________________
//   WAIT   --------\________________
//   WAIT_D ------------\____________
//
// With TV80 Core, WR goes low on T2 Rising. 
// WAIT_D signal must be ready T1 Falling. 
// WAIT can go low T2 Rising as normal or on T1 Falling. (Latter simpler)
//
// WAIT is removed, 7474B D pin connected to WAIT_P. WAIT_D connected to wait_n

// 7474 7FA
always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0) begin
        cpu_wait <= 1'b1;
    end else if(vblk == 1'b1) begin
        cpu_wait <= 1'b1;
    //end else if(cpu_clk_rise) begin
    end else if(cpu_clk_fall) begin
        cpu_wait <= ~cpu_wait_p;
    end
end

// 7474 7FB
//always_ff @(posedge masterclk) 
//begin
//    if(rst_n == 1'b0) begin
//        cpu_wait_d <= 1'b1;
//    end else if(cpu_clk_fall == 1'b1) begin
//        cpu_wait_d <= cpu_wait;
//    end
//end

// DMA Controller
fakedma dmac (
    .clk(masterclk),
    .rst_n(rst_n),
    .cen(cpu_clk_rise),

    .ena(dma_ena),
    .s_ibus(slave_shared_master_bus),
    .s_obus(dma_slave_bus),
    .m_obus(dma_master_bus),
    .m_ibus(master_shared_slave_bus),

    .busrq(cpu_busrq_inv),
    .busack(~cpu_busack),
    .dma_wait(~cpu_wait),
    .rdy(dma_rdy)
);


// Address decoder
// TODO this needs to be controlled by slave_shared_master_bus
addr_decoder ad (
    .addr(slave_shared_master_bus.addr),
    .rd_n(slave_shared_master_bus.rdn),
    .wr_n(slave_shared_master_bus.wrn),
    .mreq_n(slave_shared_master_bus.mreqn),
    .iorq_n(slave_shared_master_bus.iorqn),
    .m1_n(cpu_m1),
    .disable_decode(~cpu_wait),

    .memrd(),
    .memwr(),
    .iord(),
    .iowr(),
    .inta(cpu_bus.inta),

    .rom_ena(rom_ena),
    .ram_ena(ram_ena),
    .obj_ena(obj_ena),
    .tile_ena(tile_ena),
    .dma_ena(dma_ena),
    .io_ena(io_ena),
    .oport_ena(oport_ena)
);

// Change enable signals to encoded output for mux
prio_encoder#(SLAVE_QTY)
ena_to_muxsel (
    .ena(1'b1),
    .ins({
        oport_ena,
        io_ena,
        dma_ena,
        tile_ena,
        obj_ena,
        ram_ena,
        rom_ena
    }),

    .valid(),
    .out(bus_sel)
);

// System Bux Mux
sysmux#(MASTER_QTY, SLAVE_QTY)
sm (
    .master_ins({
        cpu_bus,
        dma_master_bus
    }),
    .master_out(slave_shared_master_bus),
    
    .slave_ins({
        rom_bus,
        ram_bus,
        obj_bus,
        tile_bus,
        dma_slave_bus,
        io_bus,
        oport_bus
    }),
    .slave_out(master_shared_slave_bus),
    
    .msel(~cpu_busack),
    .ssel(bus_sel)
);

// ROM Core
`ifdef SIMULATION
z80rom#("roms/prog/prog_rom.bin", 14, 8, 1)
`elsif ARM_LOADER
program_rom_wrapper
`else
program_rom_wrapper
`endif
cpu_rom (
    .clk(masterclk),
    .ena(rom_ena),
    .ibus(slave_shared_master_bus),
    .obus(rom_bus)

`ifdef ARM_LOADER
    ,
    .clkext(clkprogrom),
    .enaext(enprogrom),
    .weext(weprogrom),
    .addrext(addrprogrom),
    .dinext(dinprogrom),
    .doutext(doutprogrom)
`endif
);

// RAM Core
z80ram#(12)
cpu_ram (
    .clk(masterclk),
    .ena(ram_ena),
    .ibus(slave_shared_master_bus),
    .obus(ram_bus)
);

// Video Core
dkong_video vid (
    .clk(masterclk),
    .rst_n(rst_n),

    .ibus(slave_shared_master_bus),
    .tile_bus(tile_bus),
    .obj_bus(obj_bus),

    .tile_ena(tile_ena),
    .obj_ena(obj_ena),

    .grid_ena(grid_ena),
    .flip_ena(flip_ena),
    .psl2_ena(psl2_ena),
    .cref(cref),

    .cpuclk(cpuclk),
    .vblk(vblk),
    .vram_busy(),

    .htiming(pixelclk),
    .vtiming(vtiming),

    .video_valid(video_valid),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig)
);

// Sound Core
dkong_sound sou (
    .masterclk(masterclk),
    .soundclk(soundclk),
    .rst_n(rst_n),

    .vf2(vtiming[1]),
    .bg_port(bgm_port),
    .sfx_port(sfx_port),
    .audio_irq(audio_irq),
    .audio_ack(audio_ack),

    .dac_mute(dac_mute),
    .dac_out(dac_out),
    .walk_out(walk_out),
    .jump_out(jump_out),
    .crash_out(crash_out)
);

// Input Ports
always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0) begin
        in0 <= 8'b00000000;
        in1 <= 8'b00000000;
        in2 <= 8'b00000000;
        dsw0 <= 'h00;
    end else begin
        if(IN0_ENA)
            in0 <= {3'b000, p1_b1, p1_d, p1_u, p1_l, p1_r};
        if(IN1_ENA)
            in1 <= {3'b000, p2_b1, p2_d, p2_u, p2_l, p2_r};
        if(IN2_ENA)
            in2 <= {coin_sw, ~audio_ack, 2'b00, p2_sw, p1_sw, 2'b00};
    end

    if(io_ena == 1'b1 && slave_shared_master_bus.rdn == 1'b0) begin
        //casez(slave_shared_master_bus.addr)
        //'b0111_1100_0???_????: io_bus.dslave <= in0;    // 7C00h
        //'b0111_1100_1???_????: io_bus.dslave <= in1;    // 7C80h
        //'b0111_1101_0???_????: io_bus.dslave <= in2;    // 7D00h
        //'b0111_1101_1???_????: io_bus.dslave <= dsw0;   // 7D80h
        //endcase
        case(slave_shared_master_bus.addr)
        'h7C00: io_bus.dslave <= in0;    // 7C00h
        'h7C80: io_bus.dslave <= in1;    // 7C80h
        'h7D00: io_bus.dslave <= in2;    // 7D00h
        'h7D80: io_bus.dslave <= dsw0;   // 7D80h
        endcase
    end
end

assign io_bus.mwait = 1'b1;

// Bitmapped IO
always_ff @(posedge masterclk) 
begin
    if(rst_n == 1'b0) begin
        // 7C00
        bgm_port <= 4'b1111;

        // 7D00
        sfx_port <= 6'b111111;

        // 7D80
        audio_irq <= 1'b1;
        grid_ena <= 1'b1;
        flip_ena <= 1'b1;
        psl2_ena <= 1'b0;
        nmi_mask <= 1'b0;
        dma_rdy <= 1'b0;
        cref <= 2'b0;
    end else if(io_ena == 1'b1 && slave_shared_master_bus.wrn == 1'b0) begin
        case(slave_shared_master_bus.addr)
        'h7C00: bgm_port <= ~slave_shared_master_bus.dmaster[3:0];
        
        'h7D00: sfx_port[0] <= ~slave_shared_master_bus.dmaster[0];
        'h7D01: sfx_port[1] <= ~slave_shared_master_bus.dmaster[0];
        'h7D02: sfx_port[2] <= ~slave_shared_master_bus.dmaster[0];
        'h7D03: sfx_port[3] <= ~slave_shared_master_bus.dmaster[0];
        'h7D04: sfx_port[4] <= ~slave_shared_master_bus.dmaster[0];
        'h7D05: sfx_port[5] <= ~slave_shared_master_bus.dmaster[0];

        'h7D80: audio_irq <= ~slave_shared_master_bus.dmaster[0];
        'h7D81: grid_ena <= ~slave_shared_master_bus.dmaster[0];
        'h7D82: flip_ena <= ~slave_shared_master_bus.dmaster[0];
        'h7D83: psl2_ena <= slave_shared_master_bus.dmaster[0];
        'h7D84: nmi_mask <= slave_shared_master_bus.dmaster[0];
        'h7D85: dma_rdy <= slave_shared_master_bus.dmaster[0];
        'h7D86: cref[0] <= slave_shared_master_bus.dmaster[0];
        'h7D87: cref[1] <= slave_shared_master_bus.dmaster[0];
        endcase
    end
end

// OPort core
//oport op (
//    .clk(masterclk),
//    .ena(oport_ena),
//    .ibus(slave_shared_master_bus),
//    .obus(oport_bus)
//);

z80_uart#(CLKS_PER_BIT)
uart (
    .clk(masterclk),
    .rst_n(rst_n),
    .ena(oport_ena),
    .ibus(slave_shared_master_bus),
    .obus(oport_bus),

    .rx(ser_in),
    .tx(ser_out)
);

endmodule : dkong_system
