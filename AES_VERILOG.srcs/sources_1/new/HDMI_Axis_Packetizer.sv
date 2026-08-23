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
    output logic [63:0] dbg_video_beat_count,
    output logic [63:0] dbg_video_frame_count,
    output logic [6:0]  dbg_pkt_status,

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

    // Full-frame transport geometry (1280x720 RGB888, fixed):
    //   payload = 1176 bytes = 392 pixels (40+1176 = 1216 = 76 x 16-byte beats)
    //   frame   = 921600 px = 2351 full segments + one 8-pixel segment
    //             -> SEGS_PER_FRAME = 2352 (last segment = 8 px + 384 px pad)
    //   Streaming fix: SKIP_FRAMES=0 and SOF is IGNORED after the initial
    //   ARM sync. A frame closes by pixel count (2351*392 + 8 = 921600 px),
    //   never by SOF-abort. No frame is skipped or discarded, so the
    //   packetizer consumes the video stream continuously and every
    //   transported frame carries all 2352 segments.
    localparam int unsigned PX_PER_SEG     = 392;
    localparam logic [15:0] SEGS_PER_FRAME = 16'd2352;
    localparam logic [8:0]  LAST_SEG_PX    = 9'd8;   // 921600 - 2351*392
    localparam logic         SKIP_FRAMES   = 1'b0;

    typedef enum logic [1:0] {
        ST_ARM    = 2'd0,   // wait for the first real SOF
        ST_ACTIVE = 2'd1,   // capture: header + 1176-byte segments
        ST_SKIP   = 2'd2    // unreachable since the streaming fix (state
                            // encoding kept stable for the PKT_STATUS probe)
    } state_t;

    state_t state;

    // 16-byte beat packer: 1 or 3 bytes fed per cycle, beat boundary carry.
    reg [127:0] cur_beat;
    reg [15:0]  cur_keep;
    reg [127:0] nxt_beat;
    reg [15:0]  nxt_keep;
    reg [3:0]   pos;

    reg [7:0]   header_idx;    // < 40 = header phase; == 40 = payload phase
    reg [10:0]  payload_idx;   // payload bytes fed so far (0..1175)
    reg [8:0]   pixel_cnt;     // pixels in the current segment (0..391)
    reg [8:0]   pad_cnt;       // pad pixels remaining at the frame cut
    reg         capture_frame; // frame parity: capture or skip
    reg         pending_skip;  // decided at the SOF, applied after the pad
    reg         skip_first;    // consume the held first pixel of a skipped frame
    reg         skip_sof_check;// the held pixel after ARM/SKIP carries a stale SOF
    reg [31:0]  frame_id;
    reg [15:0]  segment_id;

    logic [63:0] dbg_video_beat_count_r;
    logic [63:0] dbg_video_frame_count_r;

    assign dbg_video_beat_count  = dbg_video_beat_count_r;
    assign dbg_video_frame_count = dbg_video_frame_count_r;

    // Live packetizer probe: [6] video tvalid, [5] video tready,
    // [4] video tuser/SOF, [3:2] state, [1] packet tvalid, [0] packet tready.
    assign dbg_pkt_status = {
        s_axis_video_tvalid,
        s_axis_video_tready,
        s_axis_video_tuser,
        state,
        m_axis_pkt_tvalid,
        m_axis_pkt_tready
    };

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
                8'd16: header_byte = SEGS_PER_FRAME[15:8];
                8'd17: header_byte = SEGS_PER_FRAME[7:0];
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

    reg         seg_last_pending; // the tlast latch: set at the segment's last byte,
                                  // consumed by the beat that carries it

    always_ff @(posedge aclk) begin
        logic [7:0]  fb0, fb1, fb2;
        logic [1:0]  fb_cnt;
        logic        do_feed;
        logic        seg_complete;
        logic        beat_wrap;
        logic [127:0] cb;
        logic [15:0]  ck;
        logic [127:0] nb;
        logic [15:0]  nk;
        logic [3:0]   ps;

        if (!aresetn) begin
            state               <= ST_ARM;
            capture_frame       <= 1'b0;
            pending_skip        <= 1'b0;
            skip_first          <= 1'b0;
            skip_sof_check      <= 1'b0;
            seg_last_pending    <= 1'b0;
            header_idx          <= HEADER_BYTES;
            payload_idx         <= '0;
            pixel_cnt           <= '0;
            pad_cnt             <= '0;
            frame_id            <= '0;
            segment_id          <= '0;
            cur_beat            <= '0;
            cur_keep            <= '0;
            nxt_beat            <= '0;
            nxt_keep            <= '0;
            pos                 <= '0;
            dbg_video_beat_count_r  <= '0;
            dbg_video_frame_count_r <= '0;
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

            fb0 = 8'd0; fb1 = 8'd0; fb2 = 8'd0;
            fb_cnt = 2'd0;
            do_feed = 1'b0;
            seg_complete = 1'b0;

            // ---- byte-feed decision (only when the packer is not stalled) ----
            if (!m_axis_pkt_tvalid) begin
                case (state)
                    ST_ARM: begin
                        if (cfg_enable && s_axis_video_tvalid && s_axis_video_tuser) begin
                            state <= ST_ACTIVE;
                            capture_frame <= 1'b1;
                            header_idx <= '0;
                            payload_idx <= '0;
                            pixel_cnt <= '0;
                            frame_id <= '0;
                            segment_id <= '0;
                            skip_sof_check <= 1'b1;
                        end
                    end

                    ST_SKIP: begin
                        if (skip_first) begin
                            // Consume the held first pixel of the discarded
                            // frame (it carries the SOF of the frame being
                            // skipped, not of the next one).
                            if (s_axis_video_tvalid) begin
                                skip_first <= 1'b0;
                            end
                        end else if (s_axis_video_tvalid && s_axis_video_tuser) begin
                            // The NEXT frame's first pixel: keep it, capture.
                            state <= ST_ACTIVE;
                            capture_frame <= 1'b1;
                            frame_id <= frame_id + 1'b1;
                            header_idx <= '0;
                            payload_idx <= '0;
                            pixel_cnt <= '0;
                            segment_id <= '0;
                            skip_sof_check <= 1'b1;
                        end
                    end

                    ST_ACTIVE: begin
                        if (header_idx < HEADER_BYTES) begin
                            // header phase: 1 byte per cycle
                            fb_cnt = 2'd1;
                            fb0 = header_byte(
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
                            do_feed = 1'b1;
                            if (header_idx == HEADER_BYTES-1) begin
                                header_idx <= HEADER_BYTES;  // -> payload phase
                                payload_idx <= '0;
                                pixel_cnt <= '0;
                            end else begin
                                header_idx <= header_idx + 1'b1;
                            end
                        end
                        else if (pad_cnt != 9'd0) begin
                            // pad phase: 3 zero bytes per cycle (1 pad pixel)
                            fb_cnt = 2'd3;
                            do_feed = 1'b1;
                            pad_cnt <= pad_cnt - 1'b1;
                            if (pad_cnt == 9'd1) begin
                                seg_complete = 1'b1;
                                if (pending_skip) begin
                                    state <= ST_SKIP;
                                    skip_first <= 1'b1;
                                end else begin
                                    // Frame complete (the only pad user since
                                    // the streaming fix): close it and start
                                    // the next frame.
                                    state <= ST_ACTIVE;
                                    header_idx <= '0;
                                    payload_idx <= '0;
                                    pixel_cnt <= '0;
                                    segment_id <= '0;
                                    frame_id <= frame_id + 1'b1;
                                end
                            end
                        end
                        else if (s_axis_video_tvalid && skip_sof_check) begin
                            // The held pixel after the ARM/SKIP transition: its
                            // SOF flag is stale and must not re-trigger the
                            // frame-boundary logic.
                            skip_sof_check <= 1'b0;
                            fb_cnt = 2'd3;
                            fb0 = s_axis_video_tdata[23:16];
                            fb1 = s_axis_video_tdata[15:8];
                            fb2 = s_axis_video_tdata[7:0];
                            do_feed = 1'b1;
                            payload_idx <= payload_idx + 11'd3;
                            pixel_cnt <= 9'd1;  // same increment as the normal
                                                // path, so every segment counts
                                                // identically (392 px each)
                        end
                        else if (s_axis_video_tvalid) begin
                            // payload phase: 3 bytes per cycle (1 pixel).
                            // The SOF/tuser flag is IGNORED here: the stream
                            // is consumed continuously and frames close by
                            // pixel count, never by SOF-abort.
                            fb_cnt = 2'd3;
                            fb0 = s_axis_video_tdata[23:16];
                            fb1 = s_axis_video_tdata[15:8];
                            fb2 = s_axis_video_tdata[7:0];
                            do_feed = 1'b1;
                            payload_idx <= payload_idx + 11'd3;
                            if (segment_id == SEGS_PER_FRAME-1 && pixel_cnt == LAST_SEG_PX-1) begin
                                // Frame's last real pixel fed: pad the final
                                // segment to 392 px; the pad completion closes
                                // the frame and starts the next one.
                                pad_cnt <= PX_PER_SEG - LAST_SEG_PX;
                                pixel_cnt <= pixel_cnt + 1'b1;
                            end
                            else if (pixel_cnt == PX_PER_SEG-1) begin
                                seg_complete = 1'b1;
                                segment_id <= segment_id + 1'b1;
                                pixel_cnt <= '0;
                                header_idx <= '0;
                            end else begin
                                pixel_cnt <= pixel_cnt + 1'b1;
                            end
                        end
                    end
                endcase
            end

            // ---- beat packer (1 or 3 bytes, carry across the beat boundary) ----
            cb = cur_beat; ck = cur_keep;
            nb = nxt_beat; nk = nxt_keep;
            ps = pos;
            beat_wrap = 1'b0;

            if (do_feed) begin
                if (fb_cnt == 2'd1) begin
                    if (ps < 4'd15) begin
                        cb[8*ps +: 8] = fb0;
                        ck[ps] = 1'b1;
                        ps = ps + 1'b1;
                    end else begin
                        cb[120 +: 8] = fb0;
                        ck[15] = 1'b1;
                        beat_wrap = 1'b1;
                    end
                end else begin
                    if (ps <= 4'd12) begin
                        cb[8*ps +: 8]    = fb0;
                        cb[8*ps+8 +: 8]  = fb1;
                        cb[8*ps+16 +: 8] = fb2;
                        ck[ps] = 1'b1; ck[ps+1] = 1'b1; ck[ps+2] = 1'b1;
                        ps = ps + 4'd3;
                    end else if (ps == 4'd13) begin
                        // 13+3 = 16: the beat completes exactly, no carry
                        cb[104 +: 8] = fb0;
                        cb[112 +: 8] = fb1;
                        cb[120 +: 8] = fb2;
                        ck[13] = 1'b1; ck[14] = 1'b1; ck[15] = 1'b1;
                        beat_wrap = 1'b1;
                    end else if (ps == 4'd14) begin
                        cb[112 +: 8] = fb0;
                        cb[120 +: 8] = fb1;
                        nb[0 +: 8]   = fb2;
                        ck[14] = 1'b1; ck[15] = 1'b1; nk[0] = 1'b1;
                        beat_wrap = 1'b1;
                    end else begin  // ps == 15
                        cb[120 +: 8] = fb0;
                        nb[0 +: 8]   = fb1;
                        nb[8 +: 8]   = fb2;
                        ck[15] = 1'b1; nk[0] = 1'b1; nk[1] = 1'b1;
                        beat_wrap = 1'b1;
                    end
                end

                if (beat_wrap) begin
                    m_axis_pkt_tdata  <= cb;
                    m_axis_pkt_tkeep  <= ck;
                    m_axis_pkt_tvalid <= 1'b1;
                    m_axis_pkt_tlast  <= seg_complete || seg_last_pending;
                    cb = nb; ck = nk;
                    nb = '0; nk = '0;
                    if (fb_cnt == 2'd1)      ps = 4'd0;
                    else if (ps == 4'd13)    ps = 4'd0;
                    else if (ps == 4'd14)    ps = 4'd1;
                    else                     ps = 4'd2;
                end
            end

            cur_beat <= cb; cur_keep <= ck;
            nxt_beat <= nb; nxt_keep <= nk;
            pos <= ps;

            // The tlast latch: a completion that does not land on the beat
            // boundary this cycle (the last bytes straddle a beat) is held
            // until the beat that carries it emits.
            if (seg_complete && !beat_wrap) seg_last_pending <= 1'b1;
            else if (beat_wrap)             seg_last_pending <= 1'b0;
        end
    end

    // Consume pixels in the active payload phase (not during the header/pad,
    // not when the packer stalls) and in the skip state (except the SOF
    // pixel, which is the next frame's first pixel).
    assign s_axis_video_tready =
        (state == ST_SKIP && (skip_first || !(s_axis_video_tvalid && s_axis_video_tuser))) ||
        (state == ST_ACTIVE && cfg_enable && (header_idx == HEADER_BYTES) &&
         (pad_cnt == 9'd0) && !m_axis_pkt_tvalid);

endmodule
