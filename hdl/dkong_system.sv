`include "Z80Bus.vh"

module dkong_system #(
    parameter CLKS_PER_BIT = 1,
    parameter DEBUG_WAIT_ENA = 0,
    parameter IN2_ENA = 0
)(
    input logic masterclk,
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
    
    // Controls Signals
    input logic p1_sw,
    input logic p2_sw,
    input logic coin_sw,

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

localparam MASTER_QTY = 1;
localparam SLAVE_QTY = 6;

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

logic cpu_nmi;

logic cpu_halt,
      cpu_rfsh;

// Input Ports
logic[7:0] in0, in1, in2, dsw0;

// Bitmapped IO signals
logic audio_irq,
      grid_ena,
      flip_ena,
      psl2_ena,
      nmi_mask,
      dma_rdy;
logic[1:0] cref;

// Video Signals
logic vblk;
      
// Bus Master Structs
Z80MasterBus cpu_bus;
Z80SlaveBus  master_shared_slave_bus;

// Bus Slave Structs
Z80SlaveBus  rom_bus,                   // 0000h - 3FFFh
             ram_bus,                   // 6000h - 6BFFh
             obj_bus,                   // 7000h - 73FFh
             tile_bus,                  // 7400h - 77FFh
             io_bus,                    // 7C00h - 7D87h
             oport_bus;                 // 7F00h - 7F00h
            
Z80MasterBus slave_shared_master_bus;

// Bus Signals
logic[$clog2(SLAVE_QTY)-1:0] bus_sel;

// Slave enables
logic rom_ena,
      ram_ena,
      obj_ena,
      tile_ena,
//      dma_ena,
//      bgm_ena,
//      sfx_ena,
      io_ena,
      oport_ena;
      
// DEBUG Assigns
assign debug_ahi = slave_shared_master_bus.addr[15:8];
assign debug_alo = slave_shared_master_bus.addr[7:0];
assign debug_dmaster = slave_shared_master_bus.dmaster;
assign debug_dslave = master_shared_slave_bus.dslave;
assign debug_cpu_sig = {~cpu_nmi, slave_shared_master_bus.addr == 'h0066, ~master_shared_slave_bus.mwait, ~cpu_m1, ~cpu_iorq, ~cpu_mreq, ~cpu_wr, ~cpu_rd};
assign debug_enables = {oport_ena, io_ena, 2'b00, tile_ena, obj_ena, ram_ena, rom_ena};
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
    .busrq_n(1'b1),
    
    .m1_n(cpu_m1),
    .mreq_n(cpu_mreq),
    .iorq_n(cpu_iorq),
    .rd_n(cpu_rd),
    .wr_n(cpu_wr),
    .rfsh_n(cpu_rfsh),
    .halt_n(cpu_halt),
    .busak_n(),

    .A(cpu_bus.addr),
    .di(master_shared_slave_bus.dslave),
    .dout(cpu_bus.dmaster)
);

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
    else if(vblk == 1'b1)
        cpu_nmi <= 1'b0;
end

// Wait Signal Generator:w
assign cpu_wait_p = ~cpu_mreq & (cpu_bus.addr[15:10] == 6'b0111_01) & ~tile_bus.mwait;

// 7474 7FA
always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0) begin
        cpu_wait <= 1'b1;
    end else if(vblk == 1'b1) begin
        cpu_wait <= 1'b1;
    end else if(cpuclk == 1'b1) begin
        cpu_wait <= ~cpu_wait_p;
    end
end

// 7474 7FB
always_ff @(posedge masterclk) 
begin
    if(rst_n == 1'b0) begin
        cpu_wait_d <= 1'b1;
    end else if(cpu_clk_fall == 1'b1) begin
        cpu_wait_d <= cpu_wait;
    end
end

assign cpu_bus.rdn = cpu_rd;
assign cpu_bus.wrn = cpu_wr;

// Address decoder
addr_decoder ad (
    .addr(cpu_bus.addr),
    .rd_n(cpu_rd),
    .wr_n(cpu_wr),
    .mreq_n(cpu_mreq),
    .iorq_n(cpu_iorq),
    .m1_n(cpu_m1),
    .disable_decode(~cpu_wait_d),

//    .memrd(bus_memrd),
//    .memwr(bus_memwr),
//    .iord(bus_iord),
//    .iowr(bus_iowr),
    .inta(cpu_bus.inta),

    .rom_ena(rom_ena),
    .ram_ena(ram_ena),
    .obj_ena(obj_ena),
    .tile_ena(tile_ena),
    //.dma_ena(dma_ena),
    //.bgm_ena(bgm_ena),
    //.sfx_ena(sfx_ena),
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
//        sfx_ena,
//        bgm_ena,
//        dma_ena,
        tile_ena,
        obj_ena,
        ram_ena,
        rom_ena
    }),

    .out(bus_sel)
);

// System Bux Mux
sysmux#(MASTER_QTY, SLAVE_QTY)
sm (
    .master_ins({
    	cpu_bus
    }),
    .master_out(slave_shared_master_bus),
    
    .slave_ins({
        rom_bus,
        ram_bus,
        obj_bus,
        tile_bus,
        io_bus,
        oport_bus
    }),
    .slave_out(master_shared_slave_bus),
    
    .msel(1'b0),
    .ssel(bus_sel)
);

// ROM Core
`ifdef SIMULATION
z80rom#("roms/prog/prog_rom.bin", 14)
`else
program_rom_wrapper
`endif
cpu_rom (
    .clk(masterclk),
    .ena(rom_ena),
    .ibus(slave_shared_master_bus),
    .obus(rom_bus)
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
    .vtiming(),

    .video_valid(video_valid),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig)
);

// Input Ports
always_ff @(posedge masterclk)
begin
    if(rst_n == 1'b0) begin
        in0 <= 8'b00000000;
        in1 <= 8'b00000000;
        in2 <= 8'b00000000;
        dsw0 <= 'h80;
    end else begin
        if(IN2_ENA)
            in2 <= {coin_sw, 3'b000, p2_sw, p1_sw, 2'b00};
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
        audio_irq <= 1'b1;
        grid_ena <= 1'b1;
        flip_ena <= 1'b1;
        psl2_ena <= 1'b0;
        nmi_mask <= 1'b0;
        dma_rdy <= 1'b0;
        cref <= 2'b0;
    end else if(io_ena == 1'b1 && slave_shared_master_bus.wrn == 1'b0) begin
        case(slave_shared_master_bus.addr)
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
