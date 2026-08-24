`timescale 1ns / 1ps
// NoncePrefixInject - prepends the 8-byte cleartext nonce prefix to each
// packet of the AES-GCM ciphertext stream, so one contiguous 1240 B UDP
// payload unit (8 nonce + 1216 CT + 16 tag) lands in DDR for the ring writer.
//
// Input:  aes_gcm_0/M_AXIS_CT - 128-bit beats, TKEEP all 0xFFFF, TLAST on the
//         tag beat = 77 beats = 1232 B per packet.
// Output: same stream with one extra 8-byte beat (TKEEP=0x00FF) prepended to
//         every packet's first data beat. Packet grows to 78 beats = 1240 B.
//
// Nonce source: pkt_nonce, driven by the sequencer's new "nonce_inflight"
// shadow (the nonce of the packet CURRENTLY streaming through the AES). It is
// stable across the prefix window, so it is used combinationally.
//
// Byte order (proven against the packetizer/writer byte map):
//   stream byte b maps to TDATA[8*(b mod 16)+:8], first byte = TDATA[7:0].
//   The wire prefix is nonce[63:56] first (the shim's big-endian prefix), so
//   prefix_tdata[7:0] = nonce[63:56] ... prefix_tdata[63:56] = nonce[7:0].
module NoncePrefixInject (
    input  logic         aclk,
    input  logic         aresetn,

    input  logic [127:0] s_axis_tdata,
    input  logic [15:0]  s_axis_tkeep,
    input  logic         s_axis_tvalid,
    output logic         s_axis_tready,
    input  logic         s_axis_tlast,

    input  logic [63:0]  pkt_nonce,   // nonce of the packet currently streaming

    output logic [127:0] m_axis_tdata,
    output logic [15:0]  m_axis_tkeep,
    output logic         m_axis_tvalid,
    input  logic         m_axis_tready,
    output logic         m_axis_tlast
);

    // 1 = the next input beat starts a new packet; a prefix must go out first.
    logic need_prefix;

    // Prefix beat byte map (see module header).
    logic [127:0] prefix_tdata;
    genvar gb;
    generate
        for (gb = 0; gb < 8; gb = gb + 1) begin : g_prefix_byte
            assign prefix_tdata[gb*8 +: 8] = pkt_nonce[(7-gb)*8 +: 8];
        end
    endgenerate
    assign prefix_tdata[127:64] = 64'd0;

    // Present the prefix only when a packet actually follows (s_axis_tvalid),
    // so the final packet never leaves a dangling prefix on the output.
    wire present_prefix = need_prefix && s_axis_tvalid;

    assign m_axis_tdata  = present_prefix ? prefix_tdata : s_axis_tdata;
    assign m_axis_tkeep  = present_prefix ? 16'h00FF     : s_axis_tkeep;
    assign m_axis_tlast  = present_prefix ? 1'b0         : s_axis_tlast;
    assign m_axis_tvalid = present_prefix ? 1'b1         : (s_axis_tvalid && !need_prefix);

    // Hold the input back while we emit the prefix.
    assign s_axis_tready = m_axis_tready && !need_prefix;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            need_prefix <= 1'b1;   // the very first packet also needs a prefix
        end else begin
            if (present_prefix && m_axis_tready)
                need_prefix <= 1'b0;   // prefix accepted -> pass the packet through
            else if (!need_prefix && s_axis_tvalid && s_axis_tready && s_axis_tlast)
                need_prefix <= 1'b1;   // packet end -> next beat starts a new packet
        end
    end

endmodule
