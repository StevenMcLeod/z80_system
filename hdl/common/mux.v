module mux2#(
    parameter WIDTH = 1
)(
    input wire sel,
    input wire[WIDTH-1:0] ina, inb,
    output reg[WIDTH-1:0] outy
);

always @(ina, inb, sel)
begin
    outy <= ina;
    if(sel == 1'b1) outy <= inb;
end

endmodule

module mux4#(
    parameter WIDTH = 1
)(
    input wire[1:0] sel,
    input wire[WIDTH-1:0] ina, inb, inc, ind,
    output reg[WIDTH-1:0] outy
);

always @(ina, inb, inc, ind, sel)
begin
    case(sel)
    2'b00: outy <= ina;
    2'b01: outy <= inb;
    2'b10: outy <= inc;
    2'b11: outy <= ind;
    endcase
end

endmodule
