`timescale 1ns / 1ps
// tb_packetizer - full-frame packetizer self-check.
// Feeds 3 synthetic 720p frames (921600 px each, SOF on pixel 0) and checks:
//   - 2352 segments (tlasts) per CAPTURED frame, 76 beats per segment
//   - header: MAGIC, frame_id = 0 then 2 (frame 1 skipped), segment_id 0..2351,
//     segment_count = 2352
//   - payload bytes = the known pixel pattern; last segment = 24 real + pad
module tb_packetizer;

    localparam int FRAME_PX = 1280 * 720;
    localparam int FRAMES   = 4;      // feed 4 source frames (the 4th SOF closes
                                      // the 3rd frame's final padded segment)
    localparam int SEGS     = 2352;
    localparam int BEATS    = 76;

    logic clk = 0; always #5 clk = ~clk;   // 100 MHz
    logic rstn = 0;

    logic [23:0] px_data = '0;
    logic        px_valid = 0;
    logic        px_ready;
    logic        px_last = 0;
    logic        px_user = 0;

    logic [31:0] cfg_session_id = 32'h01020304;
    logic [15:0] cfg_stream_id  = 16'hA5A5;
    logic [7:0]  cfg_ptype      = 8'h01;
    logic [7:0]  cfg_kid        = 8'h01;
    logic [15:0] cfg_pbytes     = 16'd1176;
    logic [63:0] cfg_nonce      = 64'h1122334455667788;
    logic        cfg_enable     = 0;

    logic [63:0] dbg_beats;
    logic [63:0] dbg_frames;

    logic [127:0] m_tdata;
    logic [15:0]  m_tkeep;
    logic         m_valid;
    logic         m_ready = 1'b1;
    logic         m_last;

    HDMI_Axis_Packetizer dut (
        .aclk(clk),
        .aresetn(rstn),
        .s_axis_video_tdata(px_data),
        .s_axis_video_tvalid(px_valid),
        .s_axis_video_tready(px_ready),
        .s_axis_video_tlast(px_last),
        .s_axis_video_tuser(px_user),
        .cfg_session_id(cfg_session_id),
        .cfg_stream_id(cfg_stream_id),
        .cfg_payload_type(cfg_ptype),
        .cfg_key_id(cfg_kid),
        .cfg_payload_bytes(cfg_pbytes),
        .cfg_nonce_counter(cfg_nonce),
        .cfg_enable(cfg_enable),
        .dbg_video_beat_count(dbg_beats),
        .dbg_video_frame_count(dbg_frames),
        .m_axis_pkt_tdata(m_tdata),
        .m_axis_pkt_tkeep(m_tkeep),
        .m_axis_pkt_tvalid(m_valid),
        .m_axis_pkt_tready(m_ready),
        .m_axis_pkt_tlast(m_last)
    );

    // The known pixel pattern: pixel (frame f, index i) = {f[7:0], i[7:0], i[15:8]}.
    function automatic logic [7:0] exp_byte(input int frame, input int px, input int byte_in_px);
        logic [23:0] p;
        if (px >= FRAME_PX) return 8'h00;   // pad
        p = {frame[7:0], px[7:0], px[15:8]};
        case (byte_in_px)
            0: return p[23:16];
            1: return p[15:8];
            default: return p[7:0];
        endcase
    endfunction

    int errors = 0;
    int tlast_total = 0;
    int beats_in_seg = 0;
    int segs_in_this_frame = 0;
    int expect_frame = 0;   // 0, then 2 (frame 1 skipped)
    longint beats_total = 0;

    // Handshake-driven feeder: the pixel advances exactly when consumed
    // (tvalid && tready), so tuser and tdata always change together - no
    // stale-SOF artifacts.
    reg [1:0]  feed_f;
    reg [19:0] feed_i;
    reg        feed_active;

    always @(posedge clk) begin
        logic [19:0] nxt_i;
        nxt_i = feed_i + 1'b1;
        if (!rstn) begin
            feed_active <= 1'b0;
            feed_f <= '0;
            feed_i <= '0;
            px_valid <= 1'b0;
            px_user <= 1'b0;
            px_data <= '0;
        end else if (feed_active && px_valid && px_ready) begin
            if (feed_i == FRAME_PX-1) begin
                if (feed_f == FRAMES-1) begin
                    feed_active <= 1'b0;
                    px_valid <= 1'b0;
                    px_user <= 1'b0;
                end else begin
                    feed_f <= feed_f + 1'b1;
                    feed_i <= '0;
                    px_user <= 1'b1;
                    px_data <= {6'd0, feed_f + 1'b1, 8'd0, 8'd0};
                end
            end else begin
                feed_i <= nxt_i;
                px_user <= 1'b0;
                px_data <= {6'd0, feed_f, nxt_i[7:0], nxt_i[15:8]};
            end
        end else if (!feed_active) begin
            feed_active <= 1'b1;
            px_valid <= 1'b1;
            px_user <= 1'b1;
            px_data <= {8'd0, 8'd0, 8'd0};
        end
    end

    always @(posedge clk) begin
        if (m_valid && m_ready && (beats_total+1 >= 75) && (beats_total+1 <= 78))
            $display("T%0t BEAT%0d last=%0d pend=%0d feed_i=%0d pc=%0d pos=%0d hdr=%0d", $time, beats_total+1, m_last, dut.seg_last_pending, feed_i, dut.pixel_cnt, dut.pos, dut.header_idx);
    end

    // enable, then the final report once the feeder finishes
    initial begin
        #30 rstn = 1;
        #20 cfg_enable = 1;
        wait (feed_active == 1'b1);
        wait (feed_active == 1'b0);
        #2000;
        $display("DONE beats=%0d", beats_total);
        $display("DONE tlasts=%0d (expect %0d)", tlast_total, 2 * SEGS);
        $display("DONE errors=%0d", errors);
        $display("DONE dbg_frames=%0d (fed %0d)", dbg_frames, FRAMES);
        if (tlast_total != 2 * SEGS) errors++;
        if (errors == 0) $display("PACKETIZER_TB PASS");
        else             $display("PACKETIZER_TB FAIL errors=%0d", errors);
        $finish;
    end

    // sink: parse every beat, check the headers and the payload pattern
    always @(posedge clk) begin
        if (!rstn) begin
            beats_in_seg <= 0;
            segs_in_this_frame <= 0;
        end else if (m_valid && m_ready && tlast_total < 2 * SEGS) begin
            beats_total = beats_total + 1;
            if (beats_total <= 6)
                $display("T%0t BEAT %0d data=%h keep=%h", $time, beats_total, m_tdata, m_tkeep);
            for (int b = 0; b < 16; b++) begin
                int byte_idx;
                byte_idx = beats_in_seg * 16 + b;
                if (byte_idx < 40) begin
                    case (byte_idx)
                        0: if (m_tdata[8*b +: 8] != 8'h4F) begin errors++; $display("T%0t hdr0 bad", $time); end
                        1: if (m_tdata[8*b +: 8] != 8'h56) begin errors++; $display("T%0t hdr1 bad", $time); end
                        10: if (m_tdata[8*b +: 8] != expect_frame[31:24]) begin errors++; $display("T%0t frame_id hi bad %h vs %h", $time, m_tdata[8*b +: 8], expect_frame[31:24]); end
                        11: if (m_tdata[8*b +: 8] != expect_frame[23:16]) begin errors++; $display("T%0t frame_id lo bad %h vs %h", $time, m_tdata[8*b +: 8], expect_frame[23:16]); end
                        14: if (m_tdata[8*b +: 8] != segs_in_this_frame[15:8]) begin errors++; $display("T%0t seg_id hi bad %h vs %h", $time, m_tdata[8*b +: 8], segs_in_this_frame[15:8]); end
                        15: if (m_tdata[8*b +: 8] != segs_in_this_frame[7:0]) begin errors++; $display("T%0t seg_id lo bad %h vs %h", $time, m_tdata[8*b +: 8], segs_in_this_frame[7:0]); end
                        16: if (m_tdata[8*b +: 8] != SEGS[15:8]) begin errors++; $display("T%0t seg_count hi bad", $time); end
                        17: if (m_tdata[8*b +: 8] != SEGS[7:0]) begin errors++; $display("T%0t seg_count lo bad", $time); end
                    endcase
                end else begin
                    int px_in_seg, px_global, bin_px;
                    px_in_seg = (byte_idx - 40) / 3;
                    bin_px    = (byte_idx - 40) % 3;
                    px_global = segs_in_this_frame * 392 + px_in_seg;
                    if (m_tdata[8*b +: 8] != exp_byte(expect_frame, px_global, bin_px)) begin
                        errors++;
                        if (errors < 8)
                            $display("T%0t payload bad: beat=%0d b=%0d got=%h exp=%h seg=%0d px=%0d",
                                     $time, beats_total, b, m_tdata[8*b +: 8],
                                     exp_byte(expect_frame, px_global, bin_px),
                                     segs_in_this_frame, px_global);
                    end
                end
            end
            beats_in_seg <= beats_in_seg + 1;
            if (m_last) begin
                if (beats_in_seg + 1 != BEATS) begin
                    errors++;
                    $display("T%0t segment beat count bad: %0d", $time, beats_in_seg + 1);
                end
                tlast_total = tlast_total + 1;
                beats_in_seg <= 0;
                if (segs_in_this_frame == SEGS - 1) begin
                    segs_in_this_frame <= 0;
                    if (expect_frame == 0) expect_frame = 2;
                end else begin
                    segs_in_this_frame <= segs_in_this_frame + 1;
                end
            end
        end
    end

endmodule
