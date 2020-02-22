module dkong_system_wrapper #(
    parameter CLKS_PER_BIT = 1
) (
    input wire masterclk,
    input wire rst_n,

    input wire ser_in,
    output wire ser_out,

    output wire pixelclk,
    output wire video_valid,
    output wire[2:0] r_sig,
    output wire[2:0] g_sig,
    output wire[1:0] b_sig,

    output wire[7:0] debug_ahi,
    output wire[7:0] debug_alo,
    output wire[7:0] debug_dmaster,
    output wire[7:0] debug_dslave,
    output wire[7:0] debug_cpu_sig,
    output wire[7:0] debug_enables
);

dkong_system inst (
    .masterclk(masterclk),
    .rst_n(rst_n),

    .ser_in(ser_in),
    .ser_out(ser_out),

    .pixelclk(pixelclk),
    .video_valid(video_valid),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig),

    .debug_ahi(debug_ahi),
    .debug_alo(debug_alo),
    .debug_dmaster(debug_dmaster),
    .debug_dslave(debug_dslave),
    .debug_cpu_sig(debug_cpu_sig),
    .debug_enables(debug_enables)
);

endmodule
