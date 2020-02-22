module edge_detector#(
    parameter RISE_FALLN = 1
)(
    input clk,
    input rst_n,
    input sig,
    output detect
);

reg inited;
reg last_sig;
reg detect_r;

assign detect = detect_r;

always @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        inited <= 1'b0;
        detect_r <= 1'b0;
    end else if(inited == 1'b0) begin
        inited <= 1'b1;
        last_sig <= sig;
    end else if(detect_r == 1'b0) begin
        if(RISE_FALLN == 0) begin
            if(last_sig == 1'b1 && sig == 1'b0) begin
                detect_r <= 1'b1;
            end
        end else begin
            if(last_sig == 1'b0 && sig == 1'b1) begin
                detect_r <= 1'b1;
            end
        end     
    end
end

endmodule

