module dkong_system_wrapper #(
    parameter CLKS_PER_BIT = 1,
    parameter DEBUG_WAIT_ENA = 0,
    parameter IN0_ENA = 0,
    parameter IN1_ENA = 0,
    parameter IN2_ENA = 0
) (
    input wire masterclk,
    input wire soundclk,
    input wire rst_n,

    input wire ser_in,
    output wire ser_out,

    output wire pixelclk,
    output wire video_valid,
    output wire[2:0] r_sig,
    output wire[2:0] g_sig,
    output wire[1:0] b_sig,
    
    output wire dac_mute,
    output wire[7:0] dac_out,
    output wire walk_out,
    output wire jump_out,
    output wire crash_out,

    input wire p1_r,
    input wire p1_l,
    input wire p1_u,
    input wire p1_d,
    input wire p1_b1,

    input wire p2_r,
    input wire p2_l,
    input wire p2_u,
    input wire p2_d,
    input wire p2_b1,

    input wire p1_sw,
    input wire p2_sw,
    input wire coin_sw,

    input wire clkprogrom,
    input wire enprogrom,
    input wire weprogrom,
    input wire[13:0] addrprogrom,
    input wire[7:0] dinprogrom,
    output wire[7:0] doutprogrom,

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
    IN0_ENA,
    IN1_ENA,
    IN2_ENA
) inst (
    .masterclk(masterclk),
    .soundclk(soundclk),
    .rst_n(rst_n),

    .ser_in(ser_in),
    .ser_out(ser_out),

    .pixelclk(pixelclk),
    .video_valid(video_valid),
    .r_sig(r_sig),
    .g_sig(g_sig),
    .b_sig(b_sig),

    .dac_mute(dac_mute),
    .dac_out(dac_out),
    .walk_out(walk_out),
    .jump_out(jump_out),
    .crash_out(crash_out),

    .p1_r(p1_r),
    .p1_l(p1_l),
    .p1_u(p1_u),
    .p1_d(p1_d),
    .p1_b1(p1_b1),

    .p2_r(p2_r),
    .p2_l(p2_l),
    .p2_u(p2_u),
    .p2_d(p2_d),
    .p2_b1(p2_b1),

    .p1_sw(p1_sw),
    .p2_sw(p2_sw),
    .coin_sw(coin_sw),

    .clkprogrom(clkprogrom),
    .enprogrom(enprogrom),
    .weprogrom(weprogrom),
    .addrprogrom(addrprogrom),
    .dinprogrom(dinprogrom),
    .doutprogrom(doutprogrom),

    .debug_wait(debug_wait),
    .debug_ahi(debug_ahi),
    .debug_alo(debug_alo),
    .debug_dmaster(debug_dmaster),
    .debug_dslave(debug_dslave),
    .debug_cpu_sig(debug_cpu_sig),
    .debug_enables(debug_enables)
);

endmodule
