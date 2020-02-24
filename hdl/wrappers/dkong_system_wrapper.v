module dkong_system_wrapper #(
    parameter CLKS_PER_BIT = 1,
    parameter DEBUG_WAIT_ENA = 0,
    parameter IN2_ENA = 0
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

    input wire p1_sw,
    input wire p2_sw,
    input wire coin_sw,

    input wire debug_wait,
    output wire[7:0] debug_ahi,
    output wire[7:0] debug_alo,
    output wire[7:0] debug_dmaster,
    output wire[7:0] debug_dslave,
    output wire[7:0] debug_cpu_sig,
    output wire[7:0] debug_enables
);

dkong_system#(
    CLKS_PER_BIT,
    DEBUG_WAIT_ENA,
    IN2_ENA
) inst (
    .masterclk(masterclk),
    .rst_n(rst_n),

    .ser_in(ser_in),
    .ser_out(ser_out),

    .pixelclk(pixelclk),
    .video_valid(video_valid),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig),

    .p1_sw(p1_sw),
    .p2_sw(p2_sw),
    .coin_sw(coin_sw),

    .debug_wait(debug_wait),
    .debug_ahi(debug_ahi),
    .debug_alo(debug_alo),
    .debug_dmaster(debug_dmaster),
    .debug_dslave(debug_dslave),
    .debug_cpu_sig(debug_cpu_sig),
    .debug_enables(debug_enables)
);

endmodule
