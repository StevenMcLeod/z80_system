module addr_decoder (
    // Input ctrl bus
    input logic[15:0]   addr,
    input logic         rd_n,
    input logic         wr_n,
    input logic         mreq_n,
    input logic         iorq_n,
    input logic         m1_n,
    input logic         disable_decode,

    // Output decoded bus
    output logic        memrd,
    output logic        memwr,
    output logic        iord,
    output logic        iowr,
    output logic        inta,

    // Decoded enable signals
    output logic        rom_ena,
    output logic        ram_ena,
    output logic        obj_ena,
    output logic        tile_ena,
    output logic        dma_ena,
    output logic        io_ena,
    output logic        oport_ena
);

assign memrd = ~rd_n & ~mreq_n;
assign memwr = ~wr_n & ~mreq_n;
assign iord  = ~rd_n & ~iorq_n;
assign iowr  = ~wr_n & ~iorq_n;
assign inta  = ~m1_n & ~iorq_n;

assign rom_ena = (addr >= 16'h0000 && addr <= 16'h3FFF) && ~disable_decode;
assign ram_ena = (addr >= 16'h6000 && addr <= 16'h6BFF) && ~disable_decode;
assign obj_ena = (addr >= 16'h7000 && addr <= 16'h73FF) && ~disable_decode;
assign tile_ena = (addr >= 16'h7400 && addr <= 16'h77FF) && ~disable_decode;
assign dma_ena = (addr >= 16'h7800 && addr <= 16'h780F) && ~disable_decode;
assign io_ena = (addr >= 16'h7C00 && addr <= 16'h7DFF) && ~disable_decode;
assign oport_ena = (addr == 16'h7F00) && ~disable_decode;

endmodule : addr_decoder
