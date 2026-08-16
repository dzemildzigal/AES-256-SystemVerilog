`timescale 1ns / 1ps
// Verilog wrapper for VideoBeatCounter (SystemVerilog).
// Vivado block-design module references require a plain .v top file.
module VideoBeatCounter_wrapper (
    input  wire         aclk,
    input  wire         aresetn,
    input  wire         s_axis_video_tvalid,
    output wire [63:0]  count
);

    VideoBeatCounter u_counter (
        .aclk                (aclk),
        .aresetn             (aresetn),
        .s_axis_video_tvalid (s_axis_video_tvalid),
        .count               (count)
    );

endmodule
