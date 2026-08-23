`timescale 1ns / 1ps
// Verilog wrapper for VideoStatusProbe (SystemVerilog).
module VideoStatusProbe_wrapper (
    input  wire         aclk,
    input  wire         aresetn,

    input  wire         vid_overflow,
    input  wire         vid_underflow,
    input  wire         vid_reset_async,

    output wire [63:0]  overflow_count,
    output wire [63:0]  underflow_count,
    output wire [63:0]  reset_pulse_count,
    output wire         reset_level
);

    VideoStatusProbe u_probe (
        .aclk             (aclk),
        .aresetn          (aresetn),
        .vid_overflow     (vid_overflow),
        .vid_underflow    (vid_underflow),
        .vid_reset_async  (vid_reset_async),
        .overflow_count   (overflow_count),
        .underflow_count  (underflow_count),
        .reset_pulse_count(reset_pulse_count),
        .reset_level      (reset_level)
    );

endmodule
