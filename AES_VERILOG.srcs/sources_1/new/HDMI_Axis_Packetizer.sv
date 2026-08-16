`timescale 1ns / 1ps

module HDMI_Axis_Packetizer #(
    parameter int unsigned MAX_PAYLOAD_BYTES = 1200
) (
    input  logic         aclk,
    input  logic         aresetn,

    input  logic [23:0]  s_axis_video_tdata,
    input  logic         s_axis_video_tvalid,
    output logic         s_axis_video_tready,
    input  logic         s_axis_video_tlast,
    input  logic         s_axis_video_tuser,

    input  logic [31:0]  cfg_session_id,
    input  logic [15:0]  cfg_stream_id,
    input  logic [7:0]   cfg_payload_type,
    input  logic [7:0]   cfg_key_id,
    input  logic [15:0]  cfg_payload_bytes,
    input  logic [63:0]  cfg_nonce_counter,
    input  logic         cfg_enable,

    // Free-running diagnostic counters, read back via aes_seq_0.
    // beat_count: +1 every clock s_axis_video_tvalid is high (assertion, not
    // handshake: if data arrives but is never consumed, this still climbs).
    // frame_count: +1 per accepted start-of-frame (tvalid && tready && tuser).
    output logic [63:0] dbg_video_beat_count,
    output logic [63:0] dbg_video_frame_count,

    output logic [127:0] m_axis_pkt_tdata,
    output logic [15:0]  m_axis_pkt_tkeep,
    output logic         m_axis_pkt_tvalid,
    input  logic         m_axis_pkt_tready,
    output logic         m_axis_pkt_tlast
);

    localparam logic [15:0] MAGIC = 16'h4F56;
    localparam logic [7:0]  VERSION = 8'd0;
    localparam logic [7:0]  TAG_LENGTH = 8'd16;
    localparam int unsigned HEADER_BYTES = 40;

    typedef enum logic [1:0] {
        ST_ARM     = 2'd0,   // ponytail: wait for first real frame (tuser) before packetizing;
                             // prevents a boot-time session starting with no video (see aresetn block)
        ST_HEADER  = 2'd1,
        ST_PAYLOAD = 2'd2
    } state_t;

    state_t state;

    logic [7:0]   header_idx;
    logic [10:0]  payload_idx;
    logic [31:0]  frame_id;
    logic [15:0]  segment_id;
    logic         packet_started;
    logic         saw_frame_start;

    logic [23:0]  pixel_buf;
    logic [1:0]   pixel_byte_idx;
    logic         pixel_valid;

    logic [127:0] pack_data;
    logic [15:0]  pack_keep;
    logic [4:0]   pack_count;

    logic [63:0]  dbg_video_beat_count_r;
    logic [63:0]  dbg_video_frame_count_r;

    assign dbg_video_beat_count  = dbg_video_beat_count_r;
    assign dbg_video_frame_count = dbg_video_frame_count_r;

    function automatic logic [7:0] header_byte(
        input logic [7:0] idx,
        input logic [31:0] session_id,
        input logic [15:0] stream_id,
        input logic [31:0] f_id,
        input logic [15:0] s_id,
        input logic [7:0] payload_type,
        input logic [7:0] key_id,
        input logic [63:0] nonce,
        input logic [15:0] payload_len
    );
        logic [63:0] ts;
        begin
            ts = nonce;
            case (idx)
                8'd0:  header_byte = MAGIC[15:8];
                8'd1:  header_byte = MAGIC[7:0];
                8'd2:  header_byte = VERSION;
                8'd3:  header_byte = 8'd0;
                8'd4:  header_byte = session_id[31:24];
                8'd5:  header_byte = session_id[23:16];
                8'd6:  header_byte = session_id[15:8];
                8'd7:  header_byte = session_id[7:0];
                8'd8:  header_byte = stream_id[15:8];
                8'd9:  header_byte = stream_id[7:0];
                8'd10: header_byte = f_id[31:24];
                8'd11: header_byte = f_id[23:16];
                8'd12: header_byte = f_id[15:8];
                8'd13: header_byte = f_id[7:0];
                8'd14: header_byte = s_id[15:8];
                8'd15: header_byte = s_id[7:0];
                8'd16: header_byte = 8'd0;
                8'd17: header_byte = 8'd1;  // ponytail: segment_count=1 (packet granularity for now).
                                            // Real per-video-frame segment_count needs a new
                                            // cfg_segment_count input from the sequencer;
                                            // deferred until transport/crypto is proven end-to-end.
                8'd18: header_byte = ts[63:56];
                8'd19: header_byte = ts[55:48];
                8'd20: header_byte = ts[47:40];
                8'd21: header_byte = ts[39:32];
                8'd22: header_byte = ts[31:24];
                8'd23: header_byte = ts[23:16];
                8'd24: header_byte = ts[15:8];
                8'd25: header_byte = ts[7:0];
                8'd26: header_byte = payload_type;
                8'd27: header_byte = key_id;
                8'd28: header_byte = payload_len[15:8];
                8'd29: header_byte = payload_len[7:0];
                8'd30: header_byte = nonce[63:56];
                8'd31: header_byte = nonce[55:48];
                8'd32: header_byte = nonce[47:40];
                8'd33: header_byte = nonce[39:32];
                8'd34: header_byte = nonce[31:24];
                8'd35: header_byte = nonce[23:16];
                8'd36: header_byte = nonce[15:8];
                8'd37: header_byte = nonce[7:0];
                8'd38: header_byte = TAG_LENGTH;
                default: header_byte = 8'd0;
            endcase
        end
    endfunction

    always_ff @(posedge aclk) begin
        logic [127:0] next_pack_data;
        logic [15:0]  next_pack_keep;
        logic [4:0]   next_pack_count;
        logic [7:0]   emit_byte;
        logic         emit_valid;
        logic         emit_last;

        if (!aresetn) begin
            state               <= ST_ARM;
            header_idx          <= '0;
            payload_idx         <= '0;
            frame_id            <= '0;
            segment_id          <= '0;
            packet_started      <= 1'b0;
            saw_frame_start     <= 1'b0;
            pixel_buf           <= '0;
            pixel_byte_idx      <= '0;
            pixel_valid         <= 1'b0;
            dbg_video_beat_count_r  <= '0;
            dbg_video_frame_count_r <= '0;
            pack_data           <= '0;
            pack_keep           <= '0;
            pack_count          <= '0;
            m_axis_pkt_tdata    <= '0;
            m_axis_pkt_tkeep    <= '0;
            m_axis_pkt_tvalid   <= 1'b0;
            m_axis_pkt_tlast    <= 1'b0;
        end else begin
            if (s_axis_video_tvalid) begin
                dbg_video_beat_count_r <= dbg_video_beat_count_r + 1'b1;
            end
            if (s_axis_video_tvalid && s_axis_video_tready && s_axis_video_tuser) begin
                dbg_video_frame_count_r <= dbg_video_frame_count_r + 1'b1;
            end

            if (m_axis_pkt_tvalid && m_axis_pkt_tready) begin
                m_axis_pkt_tvalid <= 1'b0;
                m_axis_pkt_tlast  <= 1'b0;
            end

            next_pack_data  = pack_data;
            next_pack_keep  = pack_keep;
            next_pack_count = pack_count;
            emit_valid      = 1'b0;
            emit_last       = 1'b0;
            emit_byte       = 8'd0;

            if (!m_axis_pkt_tvalid) begin
                if (state == ST_ARM) begin
                    if (cfg_enable && s_axis_video_tvalid && s_axis_video_tuser) begin
                        state <= ST_HEADER;
                    end
                    // s_axis_video_tready is 0 here (existing assign only asserts it in
                    // ST_PAYLOAD), so this beat is only observed, not consumed. It gets
                    // captured for real once ST_PAYLOAD starts.
                end else if (state == ST_HEADER) begin
                    emit_valid = 1'b1;
                    emit_byte  = header_byte(
                        header_idx,
                        cfg_session_id,
                        cfg_stream_id,
                        frame_id,
                        segment_id,
                        cfg_payload_type,
                        cfg_key_id,
                        cfg_nonce_counter,
                        (cfg_payload_bytes == 16'd0) ? MAX_PAYLOAD_BYTES[15:0] : cfg_payload_bytes
                    );
                    if (header_idx == HEADER_BYTES-1) begin
                        state      <= ST_PAYLOAD;
                        header_idx <= '0;
                    end else begin
                        header_idx <= header_idx + 1'b1;
                    end
                end else begin
                    if (!pixel_valid && s_axis_video_tvalid) begin
                        pixel_buf      <= s_axis_video_tdata;
                        pixel_valid    <= 1'b1;
                        pixel_byte_idx <= 2'd0;
                        if (s_axis_video_tuser) begin
                            saw_frame_start <= 1'b1;
                        end
                    end

                    if (pixel_valid) begin
                        emit_valid = 1'b1;
                        case (pixel_byte_idx)
                            2'd0: emit_byte = pixel_buf[23:16];
                            2'd1: emit_byte = pixel_buf[15:8];
                            default: emit_byte = pixel_buf[7:0];
                        endcase

                        if (pixel_byte_idx == 2'd2) begin
                            pixel_valid    <= 1'b0;
                            pixel_byte_idx <= 2'd0;
                        end else begin
                            pixel_byte_idx <= pixel_byte_idx + 1'b1;
                        end

                        if (payload_idx == ((cfg_payload_bytes == 16'd0) ? MAX_PAYLOAD_BYTES[15:0] : cfg_payload_bytes)-1) begin
                            emit_last   = 1'b1;
                            state       <= ST_HEADER;
                            payload_idx <= '0;

                            if (saw_frame_start) begin
                                if (packet_started) begin
                                    frame_id <= frame_id + 1'b1;
                                end
                                segment_id <= '0;
                                saw_frame_start <= 1'b0;
                            end else begin
                                segment_id <= segment_id + 1'b1;
                            end
                            packet_started <= 1'b1;
                        end else begin
                            payload_idx <= payload_idx + 1'b1;
                        end
                    end
                end

                if (emit_valid) begin
                    next_pack_data[8*next_pack_count +: 8] = emit_byte;
                    next_pack_keep[next_pack_count] = 1'b1;
                    next_pack_count = next_pack_count + 1'b1;

                    if ((next_pack_count == 16) || emit_last) begin
                        m_axis_pkt_tdata  <= next_pack_data;
                        m_axis_pkt_tkeep  <= next_pack_keep;
                        m_axis_pkt_tvalid <= 1'b1;
                        m_axis_pkt_tlast  <= emit_last;
                        next_pack_data    = '0;
                        next_pack_keep    = '0;
                        next_pack_count   = '0;
                    end
                end
            end

            pack_data  <= next_pack_data;
            pack_keep  <= next_pack_keep;
            pack_count <= next_pack_count;
        end
    end

    assign s_axis_video_tready = cfg_enable && (state == ST_PAYLOAD) && !pixel_valid && !m_axis_pkt_tvalid;

endmodule
