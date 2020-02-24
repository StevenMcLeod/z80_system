module fb_tb();

// 1 / 61.44 MHz
time clkspeed = 16276ps;
time vgaspeed = 39722ps;
logic clk, vgaclk, rst_n;
logic[2:0] r_sig;
logic[2:0] g_sig;
logic[1:0] b_sig;

logic pixelclk;
logic valid_video;

initial
begin
    clk <= 1'b0;
    
    forever begin
        #(clkspeed/2) clk <= ~clk;
    end
end

initial begin
    vgaclk <= 1'b0;

    forever begin
        #(vgaspeed/2) vgaclk <= ~vgaclk;
    end
end

initial begin
    rst_n <= 1'b0;
    
    repeat(20) begin
        @(posedge clk);
    end
    
    rst_n <= 1'b1;
end

dkong_system#(1)
dkong (
    .masterclk(clk),
    .rst_n(rst_n),

    .pixelclk(pixelclk),
    .video_valid(valid_video),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig)
);

//framedoubler fd (
framedoubler_slow fd(
    .masterclk(clk),
    .in_rst_n(rst_n),

    .in_pixclk(pixelclk),
    .in_valid(valid_video),
    .in_r(r_sig),
    .in_g(g_sig),
    .in_b(b_sig),

    .out_rst_n(rst_n),
    .out_pixclk(vgaclk)
);


endmodule
