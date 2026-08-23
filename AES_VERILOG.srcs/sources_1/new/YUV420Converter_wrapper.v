`timescale 1ns / 1ps
// Verilog wrapper for YUV420Converter (SystemVerilog).
// Vivado block-design module references require a plain .v top file.
module YUV420Converter_wrapper (
    input  wire         aclk,
    input  wire         aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_video TDATA" *)
    input  wire [23:0]  s_axis_video_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_video TVALID" *)
    input  wire         s_axis_video_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_video TREADY" *)
    output wire         s_axis_video_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_video TLAST" *)
    input  wire         s_axis_video_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_video TUSER" *)
    input  wire         s_axis_video_tuser,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axis_video, TDATA_NUM_BYTES 3, TUSER_WIDTH 1, HAS_TREADY 1, HAS_TLAST 1, FREQ_HZ 142857132, PHASE 0.0" *)

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_video TDATA" *)
    output wire [23:0]  m_axis_video_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_video TVALID" *)
    output wire         m_axis_video_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_video TREADY" *)
    input  wire         m_axis_video_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_video TLAST" *)
    output wire         m_axis_video_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_video TUSER" *)
    output wire         m_axis_video_tuser,
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axis_video, TDATA_NUM_BYTES 3, TUSER_WIDTH 1, HAS_TREADY 1, HAS_TLAST 1, FREQ_HZ 142857132, PHASE 0.0" *)

    output wire [63:0]  in_beats,
    output wire [63:0]  out_beats
);

    YUV420Converter u_conv (
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
        .in_beats             (in_beats),
        .out_beats            (out_beats)
    );

endmodule
