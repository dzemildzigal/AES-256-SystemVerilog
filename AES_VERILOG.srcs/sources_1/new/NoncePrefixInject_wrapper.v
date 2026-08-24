`timescale 1ns / 1ps
// Verilog wrapper for NoncePrefixInject (SystemVerilog).
// Vivado block-design module references require a plain .v top file.

module NoncePrefixInject_wrapper (
    input  wire         aclk,
    input  wire         aresetn,

    input  wire [127:0] S_AXIS_TDATA,
    input  wire [15:0]  S_AXIS_TKEEP,
    input  wire         S_AXIS_TVALID,
    output wire         S_AXIS_TREADY,
    input  wire         S_AXIS_TLAST,

    input  wire [63:0]  pkt_nonce,

    output wire [127:0] M_AXIS_TDATA,
    output wire [15:0]  M_AXIS_TKEEP,
    output wire         M_AXIS_TVALID,
    input  wire         M_AXIS_TREADY,
    output wire         M_AXIS_TLAST
);

    NoncePrefixInject u_nonce_prefix (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axis_tdata  (S_AXIS_TDATA),
        .s_axis_tkeep  (S_AXIS_TKEEP),
        .s_axis_tvalid (S_AXIS_TVALID),
        .s_axis_tready (S_AXIS_TREADY),
        .s_axis_tlast  (S_AXIS_TLAST),
        .pkt_nonce     (pkt_nonce),
        .m_axis_tdata  (M_AXIS_TDATA),
        .m_axis_tkeep  (M_AXIS_TKEEP),
        .m_axis_tvalid (M_AXIS_TVALID),
        .m_axis_tready (M_AXIS_TREADY),
        .m_axis_tlast  (M_AXIS_TLAST)
    );

endmodule
