`timescale 1ns / 1ps
// Verilog wrapper for HDMI_Axis_Packetizer (SystemVerilog).
// Vivado block-design module references require a plain .v top file.

module HDMI_Axis_Packetizer_wrapper #(
    parameter MAX_PAYLOAD_BYTES = 1200
)(
    input  wire         aclk,
    input  wire         aresetn,

    input  wire [23:0]  s_axis_video_tdata,
    input  wire         s_axis_video_tvalid,
    output wire         s_axis_video_tready,
    input  wire         s_axis_video_tlast,
    input  wire         s_axis_video_tuser,

    input  wire [31:0]  cfg_session_id,
    input  wire [15:0]  cfg_stream_id,
    input  wire [7:0]   cfg_payload_type,
    input  wire [7:0]   cfg_key_id,
    input  wire [15:0]  cfg_payload_bytes,
    input  wire [63:0]  cfg_nonce_counter,
    input  wire         cfg_enable,

    output wire [127:0] m_axis_pkt_tdata,
    output wire [15:0]  m_axis_pkt_tkeep,
    output wire         m_axis_pkt_tvalid,
    input  wire         m_axis_pkt_tready,
    output wire         m_axis_pkt_tlast
);

    HDMI_Axis_Packetizer #(
        .MAX_PAYLOAD_BYTES(MAX_PAYLOAD_BYTES)
    ) u_packetizer (
        .aclk                (aclk),
        .aresetn             (aresetn),
        .s_axis_video_tdata  (s_axis_video_tdata),
        .s_axis_video_tvalid (s_axis_video_tvalid),
        .s_axis_video_tready (s_axis_video_tready),
        .s_axis_video_tlast  (s_axis_video_tlast),
        .s_axis_video_tuser  (s_axis_video_tuser),
        .cfg_session_id      (cfg_session_id),
        .cfg_stream_id       (cfg_stream_id),
        .cfg_payload_type    (cfg_payload_type),
        .cfg_key_id          (cfg_key_id),
        .cfg_payload_bytes   (cfg_payload_bytes),
        .cfg_nonce_counter   (cfg_nonce_counter),
        .cfg_enable          (cfg_enable),
        .m_axis_pkt_tdata    (m_axis_pkt_tdata),
        .m_axis_pkt_tkeep    (m_axis_pkt_tkeep),
        .m_axis_pkt_tvalid   (m_axis_pkt_tvalid),
        .m_axis_pkt_tready   (m_axis_pkt_tready),
        .m_axis_pkt_tlast    (m_axis_pkt_tlast)
    );

endmodule
