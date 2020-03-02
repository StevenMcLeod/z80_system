`timescale 1ns/1ps

`include "../Z80Bus.vh"

module video_tb();

// 1 / 61.44 MHz
time clkspeed = 16276ps;
logic clk, rst_n;
logic[2:0] r_sig;
logic[2:0] g_sig;
logic[1:0] b_sig;

logic[9:0] htiming;
logic pixelclk;
logic vram_busy;
logic do_write;

Z80MasterBus master;
logic do_ena;

assign master.inta = 1'b1;

assign pixelclk = htiming[0];

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
    int count = 0;

    //fifo_d = $fopen("fifo.in", "w");
    fifo_d = $fopen("screen.out", "wb");
    if(fifo_d == 0)
        $fatal("Cannot open fifo");

    forever begin
        @(posedge pixelclk);
        if(do_write == 1'b1) begin
            $fwrite(fifo_d, "%c", ~{b_sig, g_sig, r_sig});
            $display("%d", count);
            ++count;
        end
        
        if(count == 256*224) begin
            $fclose(fifo_d);
            $finish();
        end
    end
end

initial begin
    int i;
    bit[7:0] tiledump['h400];

`ifdef TESTFILE
    begin
        integer tilefile;
        
        // Load test file
        tilefile = $fopen(`TESTFILE, "r");
        if(tilefile == 0)
            $fatal("Could not open test file");

        for(int j = 0; j < $size(tiledump); ++j) begin
            bit[8:0] c;
            c = $fgetc(tilefile);
            if(c == 'h1FF)
                $fatal("File not long enough");

            tiledump[j] = c[7:0];
        end
        $fclose(tilefile);
    end

`else
    // Predetermined pattern
    i = 'h000;

    for(int j = 0; j < $size(tiledump); ++j) begin
        tiledump[j] = j & 'hFF;
    end

`endif

    @(posedge rst_n);

    master.rdn = 1'b1;
    do_ena = 1'b0;
    while(i < 'h400) begin
        @(posedge clk);
        if(vram_busy == 1'b0) begin
            master.addr = i;
            master.dmaster = tiledump[i & 'h3FF];
            master.wrn = 1'b0;
            do_ena = 1'b1;

            ++i;
        end else begin
            master.wrn = 1'b1;
            do_ena = 1'b0;
        end
    end

    master.addr = 0;
    master.dmaster = 0;
    master.wrn = 1'b1;
end

dkong_video myvid (
    .clk(clk),
    .rst_n(rst_n),

    .ibus(master),
    .tile_bus(),
    .obj_bus(),

    .tile_ena(1'b0),
    .obj_ena(do_ena),

    .grid_ena(1'b0),
    .flip_ena(1'b1),
    .psl2_ena(1'b0),
    .cref(2'b00),

    .cpuclk(),
    .vblk(),
    .vram_busy(vram_busy),

    .htiming(htiming),
    .vtiming(),

    .video_valid(do_write),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig)
);

endmodule
