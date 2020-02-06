module prio_encoder #(
    parameter INPUT_QTY
) (
    input logic                         ena,
    input logic[INPUT_QTY-1:0]          ins,
    
    output logic                        valid,
    output logic[$clog2(INPUT_QTY)-1:0] out
);

always_comb
begin
    out <= '0;
    valid <= 1'b0;
    
    if(ena == 1'b1) begin
        for(int i = 0; i < INPUT_QTY; ++i) begin
            if(ins[i] == 1'b1) begin
                valid <= 1'b1;
                out <= i;
            end
        end
    end
end

endmodule : prio_encoder
