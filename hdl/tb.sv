//`timescale 1ns / 1ps

module tb();

localparam real CLKFREQ = 4000000;
localparam real SERFREQ = 9600;
localparam int CLKS_PER_BIT = int'(CLKFREQ / SERFREQ);

time clkspeed = 250ns;
logic clk, rst_n;
logic ser_in, ser_out;

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

endmodule
