module addr_decoder (
    // Input ctrl bus
    input logic[15:0]   addr,
    input logic         rd_n,
    input logic         wr_n,
    input logic         mreq_n,
    input logic         iorq_n,
    input logic         m1_n,

    // Output decoded bus
    output logic        memrd,
    output logic        memwr,
    output logic        iord,
    output logic        iowr,
    output logic        inta,

    // Decoded enable signals
    output logic        rom_ena,
    output logic        oport_ena
);

assign memrd = ~rd_n & ~mreq_n;
assign memwr = ~wr_n & ~mreq_n;
assign iord  = ~rd_n & ~iorq_n;
assign iowr  = ~wr_n & ~iorq_n;
assign inta  = ~m1_n & ~iorq_n;

assign rom_ena = (addr >= 16'h0000 && addr <= 16'h7FFF);
assign oport_ena = (addr == 16'h8000);

endmodule : addr_decoder
