`include "Z80Bus.vh"

module z80test#(
    parameter CLKS_PER_BIT
)(
    input logic masterclk,
    input logic reset_n,

    // UART signals
    input logic ser_in,
    output logic ser_out,
    
    // Debug signals
    output logic[7:0] debug_ahi,
    output logic[7:0] debug_alo,
    output logic[7:0] debug_dmaster,
    output logic[7:0] debug_dslave,
    output logic[7:0] debug_cpu_sig,
    output logic[7:0] debug_enables
);

localparam SLAVE_QTY = 2;



/*
 *  SIGNALS
 *
 */

logic cpuclk;

// CPU signals
logic cpu_mreq,
      cpu_iorq,
      cpu_rd,
      cpu_wr,
      cpu_m1;

logic cpu_halt,
      cpu_rfsh;
      
// Bus Master Structs
Z80MasterBus cpu_bus;
Z80SlaveBus  master_shared_slave_bus;

// Bus Slave Structs
Z80SlaveBus  rom_bus;
Z80SlaveBus  oport_bus;
Z80MasterBus slave_shared_master_bus;  

// Bus Signals
logic[$clog2(SLAVE_QTY)-1:0] bus_sel;

// Slave enables
logic rom_ena,
      oport_ena;
      
// DEBUG Assigns
assign debug_ahi = slave_shared_master_bus.addr[15:8];
assign debug_alo = slave_shared_master_bus.addr[7:0];
assign debug_dmaster = slave_shared_master_bus.dmaster;
assign debug_dslave = master_shared_slave_bus.dslave;
assign debug_cpu_sig = {~cpu_rfsh, ~cpu_halt, ~master_shared_slave_bus.mwait, ~cpu_m1, ~cpu_iorq, ~cpu_mreq, ~cpu_wr, ~cpu_rd};
assign debug_enables = {ser_out, ser_in, masterclk, ~reset_n, 2'b00, oport_ena, rom_ena};
      
// Clock divider
always @(posedge masterclk)
begin
    if(reset_n == 1'b0)
        cpuclk <= 1'b0;
    else
        cpuclk <= ~cpuclk;
end

// Z80 Core
tv80n mycpu (
    .reset_n(reset_n),
    .clk(masterclk),
    
    .wait_n(master_shared_slave_bus.mwait),
    .int_n(1'b1),
    .nmi_n(1'b1),
    .busrq_n(1'b1),
    
    .m1_n(cpu_m1),
    .mreq_n(cpu_mreq),
    .iorq_n(cpu_iorq),
    .rd_n(cpu_rd),
    .wr_n(cpu_wr),
    .rfsh_n(cpu_rfsh),
    .halt_n(cpu_halt),
    //.busak_n(),

    .A(cpu_bus.addr),
    .di(master_shared_slave_bus.dslave),
    .dout(cpu_bus.dmaster)
);

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

//    .memrd(bus_memrd),
//    .memwr(bus_memwr),
//    .iord(bus_iord),
//    .iowr(bus_iowr),
    .inta(cpu_bus.inta),

    .rom_ena(rom_ena),
    .oport_ena(oport_ena)
);

// Change enable signals to encoded output for mux
prio_encoder#(SLAVE_QTY)
ena_to_muxsel (
    .ena(1'b1),
    .ins({
        oport_ena,
        rom_ena
    }),

    .out(bus_sel)
);

// System Bux Mux
sysmux#(1, SLAVE_QTY)
sm (
    .master_ins({
    	cpu_bus
    }),
    .master_out(slave_shared_master_bus),
    
    .slave_ins({
        rom_bus,
        oport_bus
    }),
    .slave_out(master_shared_slave_bus),
    
    .msel(1'b0),
    .ssel(bus_sel)
);

// ROM Core
//rom#("bin/program.bin", 15)
//rom#("U:/ENSC452/z80_system_sources/bin/program.bin", 15)
//myrom (
//    .clk(masterclk),
//    .ena(rom_ena),
//    .ibus(slave_shared_master_bus),
//    .obus(rom_bus)
//);
z80_rom_wrapper myrom (
    .clk(masterclk),
    .ena(rom_ena),
    .ibus(slave_shared_master_bus),
    .obus(rom_bus)
);

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
    .rst_n(reset_n),
    .ena(oport_ena),
    .ibus(slave_shared_master_bus),
    .obus(oport_bus),

    .rx(ser_in),
    .tx(ser_out)
);

endmodule : z80test
