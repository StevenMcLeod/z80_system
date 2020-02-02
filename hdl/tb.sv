//`timescale 1ns / 1ps

module tb();

time clkspeed = 250ns;
logic clk, rst_n;

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

z80test dut(
    .masterclk(clk),
    .reset_n(rst_n)
);

endmodule
