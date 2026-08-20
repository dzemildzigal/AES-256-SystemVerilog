`timescale 1ns / 1ps
// clk_mux_ctrl - glitch-controlled 3-way clock mux for the AES/design domain.
//
// Two cascaded BUFGMUX_CTRL primitives select one of three free-running
// MMCM outputs (50 / 75 / 100 MHz). The _CTRL variant switches on safe clock
// edges, and the domain is held in reset during any switch anyway.
//
//   sel = 00 -> clk_in0 (50 MHz)
//   sel = 01 -> clk_in1 (75 MHz)
//   sel = 10 -> clk_in2 (100 MHz)

module clk_mux_ctrl (
    input  wire       clk_in0,
    input  wire       clk_in1,
    input  wire       clk_in2,
    input  wire [1:0] sel,
    output wire       clk_out
);

    wire mux0_out;

    BUFGMUX_CTRL u_mux01 (
        .O  (mux0_out),
        .I0 (clk_in0),
        .I1 (clk_in1),
        .S  (sel[0])
    );

    BUFGMUX_CTRL u_mux2 (
        .O  (clk_out),
        .I0 (mux0_out),
        .I1 (clk_in2),
        .S  (sel[1])
    );

endmodule
