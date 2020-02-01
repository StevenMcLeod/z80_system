`include "Z80Bus.vh"

module oport(
    input logic         clk,
    input logic         rst_n,
    input logic         ena,
    input Z80MasterBus  ibus
);

always_ff @(posedge clk)
begin
    if(ena == 1'b1) begin
        $write("%c", ibus.dmaster);
    end
end

endmodule : oport