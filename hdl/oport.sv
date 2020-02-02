`include "Z80Bus.vh"

module oport(
    input logic         clk,
    input logic         rst_n,
    input logic         ena,
    input Z80MasterBus  ibus,
    output Z80SlaveBus  obus
);

assign obus.dslave = '0;
assign obus.mwait = 1'b1;

logic write_delay;

always_ff @(posedge clk)
begin
    if(rst_n)
        write_delay <= 1'b0;

    else if(ena == 1'b1) begin
        write_delay <= 1'b1;
    end else if(write_delay == 1'b1) begin
        write_delay <= 1'b0;
        $write("%c", ibus.dmaster);
    end
end

endmodule : oport
