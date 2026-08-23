`timescale 1ns / 1ps
// Verilog wrapper for VideoBeatCounter (SystemVerilog).
// Vivado block-design module references require a plain .v top file.
module VideoBeatCounter_wrapper (
    input  wire         aclk,
    input  wire         aresetn,

    input  wire [23:0]  s_axis_video_tdata,
    input  wire         s_axis_video_tvalid,
    output wire         s_axis_video_tready,
    input  wire         s_axis_video_tlast,
    input  wire         s_axis_video_tuser,

    output wire [23:0]  m_axis_video_tdata,
    output wire         m_axis_video_tvalid,
    input  wire         m_axis_video_tready,
    output wire         m_axis_video_tlast,
    output wire         m_axis_video_tuser,

    output wire [63:0]  count,
    output wire [31:0]  valid_cycles,
    output wire [31:0]  ready_cycles
);

    VideoBeatCounter u_counter (
        .aclk                 (aclk),
        .aresetn              (aresetn),
        .s_axis_video_tdata   (s_axis_video_tdata),
        .s_axis_video_tvalid  (s_axis_video_tvalid),
        .s_axis_video_tready  (s_axis_video_tready),
        .s_axis_video_tlast   (s_axis_video_tlast),
        .s_axis_video_tuser   (s_axis_video_tuser),
        .m_axis_video_tdata   (m_axis_video_tdata),
        .m_axis_video_tvalid  (m_axis_video_tvalid),
        .m_axis_video_tready  (m_axis_video_tready),
        .m_axis_video_tlast   (m_axis_video_tlast),
        .m_axis_video_tuser   (m_axis_video_tuser),
        .count                (count),
        .valid_cycles         (valid_cycles),
        .ready_cycles         (ready_cycles)
    );

endmodule
