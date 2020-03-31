`ifdef SIMULATION
`timescale 1ns/1ns
`endif

module sound_tb();

// 1 / 6.000 MHz
time masterspeed = 16276ps;
time soundspeed = 166666ps;
time vf2speed = 250us;
time samplespeed = 20833ns;

logic masterclk, soundclk, noiseclk, rst_n;
logic sampleclk;

logic[7:0] dac_out;
logic dac_mute;

initial
begin
    masterclk <= 1'b0;

    forever begin
        #(masterspeed/2) masterclk <= ~masterclk;
    end
end

initial
begin
    soundclk <= 1'b0;
    
    forever begin
        #(soundspeed/2) soundclk <= ~soundclk;
    end
end

initial
begin
    noiseclk <= 1'b0;

    forever begin
        #(vf2speed/2) noiseclk <= ~noiseclk;
    end
end

initial begin
    sampleclk <= 1'b0;
    forever begin
        #(samplespeed/2) sampleclk <= ~sampleclk;
    end
end

initial begin
    rst_n <= 1'b0;
    
    repeat(24) begin
        @(posedge soundclk);
    end
    
    rst_n <= 1'b1;
end

initial 
begin
    integer outfile;

    outfile = $fopen("dkong_sound.pcm", "wb");
    if(outfile == 0)
        $fatal("Could not open file for write");

    repeat(48000) begin
        @(posedge sampleclk);
        assert (!$isunknown(dac_out)) else $fatal("dac_out value unknown!");
        $fwrite(outfile, "%c", dac_out);
    end

    $fclose(outfile);
    $finish;
end

dkong_sound dut (
    .masterclk(masterclk),
    .soundclk(soundclk),
    .rst_n(rst_n),

    .vf2(noiseclk),
    .bg_port(~4'b0100),
    .sfx_port(~6'b000000),
    .audio_irq(1'b1),
    .audio_ack(),

    .dac_mute(dac_mute),
    .dac_out(dac_out),
    .walk_out(),
    .jump_out(),
    .crash_out()
);

endmodule
