module game_tb();

// 1 / 61.44 MHz
time clkspeed = 16276ps;
logic clk, rst_n;
logic[2:0] r_sig;
logic[2:0] g_sig;
logic[1:0] b_sig;

logic pixelclk;
logic do_write;

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

initial begin
    integer fifo_d;

    //fifo_d = $fopen("fifo.in", "w");
    fifo_d = $fopen("screen.out", "w");
    if(fifo_d == 0)
        $fatal("Cannot open fifo");

    forever begin
        @(posedge pixelclk);
        if(do_write == 1'b1)
            $fwrite(fifo_d, "%c", ~{b_sig, g_sig, r_sig});
    end
end

dkong_system#(1)
dkong (
    .masterclk(clk),
    .rst_n(rst_n),

    .ser_in(1'b1),
    .ser_out(),

    .pixelclk(pixelclk),
    .video_valid(do_write),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig)
);

endmodule
