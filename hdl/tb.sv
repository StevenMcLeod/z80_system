//`timescale 1ns / 1ps

module tb();

localparam real CLKFREQ = 4000000;
localparam real SERFREQ = 9600;
localparam int CLKS_PER_BIT = int'(CLKFREQ / SERFREQ);

time clkspeed = 250ns;
logic clk, rst_n;
logic ser_in, ser_out;

logic ser_valid;
logic[7:0] ser_data;

assign ser_in = 1'b1;

initial
begin
    clk <= 1'b0;
    
    forever begin
        #(clkspeed/2) clk <= ~clk;
    end
end

initial begin
    rst_n <= 1'b0;
    
    repeat(4) begin
        @(posedge clk);
    end
    
    rst_n <= 1'b1;
end

z80test#(CLKS_PER_BIT)
dut(
    .masterclk(clk),
    .reset_n(rst_n),

    .ser_in(ser_in),
    .ser_out(ser_out)
);

uart_rx#(CLKS_PER_BIT)
rx (
    .i_Clock(clk),
    .i_Rst_n(rst_n),
    .i_Rx_Serial(ser_out),
    .o_Rx_DV(ser_valid),
    .o_Rx_Byte(ser_data)
);

always @(posedge clk)
begin
    if(ser_valid == 1'b1) begin
        $write("%c", ser_data);
        
        if(ser_data == 8'h7E)
            $finish;
    end
end

endmodule
