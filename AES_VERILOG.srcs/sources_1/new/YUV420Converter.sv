`timescale 1ns / 1ps
// RGB888 -> YUV 4:2:0 converter (packed output: 2 beats per 2x2 block:
//   beat0 = {Y00, Y01, Cb}, beat1 = {Y10, Y11, Cr}).
//
// Sits between the v_vid_in coupler output and the CDC FIFO. The coupler's
// output must be consumed at full rate: v_vid_in resets its input formatter
// on its internal FIFO overflow (VID_RESET = vid_reset | overflow), which
// drops the rest of the frame - the root cause of the 6.7-lines/frame stall.
// This converter therefore only drops s_axis_tready when its one-beat output
// register is occupied; the coupler's own 4096-px FIFO absorbs those short
// stalls, so the overflow->reset frame-drop loop never triggers.
//
// Line buffers: even lines store full-res Y + pair chroma; odd lines emit
// Y for both lines plus the vertical/horizontal chroma average. tuser (SOF)
// is passed on the first emitted beat of each frame; tlast is unused by the
// downstream packetizer (frames close by beat count) and tied low.
module YUV420Converter (
    input  logic         aclk,
    input  logic         aresetn,

    input  logic [23:0]  s_axis_video_tdata,
    input  logic         s_axis_video_tvalid,
    output logic         s_axis_video_tready,
    input  logic         s_axis_video_tlast,
    input  logic         s_axis_video_tuser,

    output logic [23:0]  m_axis_video_tdata,
    output logic         m_axis_video_tvalid,
    input  logic         m_axis_video_tready,
    output logic         m_axis_video_tlast,
    output logic         m_axis_video_tuser,

    output logic [63:0]  in_beats,
    output logic [63:0]  out_beats
);
    // ---- BT.601 RGB->YUV (integer, full range) ----
    wire [7:0] R = s_axis_video_tdata[23:16];
    wire [7:0] G = s_axis_video_tdata[15:8];
    wire [7:0] B = s_axis_video_tdata[7:0];
    wire [7:0] Y  = (8'd77 * R + 8'd150 * G + 8'd29 * B) >> 8;
    wire signed [16:0] cb_acc = -43*$signed({9'd0, R}) - 85*$signed({9'd0, G}) + 128*$signed({9'd0, B});
    wire signed [16:0] cr_acc = 128*$signed({9'd0, R}) - 107*$signed({9'd0, G}) - 21*$signed({9'd0, B});
    wire [7:0] Cb = 8'd128 + cb_acc[15:8];
    wire [7:0] Cr = 8'd128 + cr_acc[15:8];

    // ---- line buffers (even-line full-res Y, even-line pair chroma) ----
    logic [7:0]  y_line  [0:1279];
    logic [15:0] ch_line [0:639];

    logic [10:0] x;
    logic        even_line;
    logic        sof_pending;
    logic        out_beat1;
    logic [23:0] beat1_reg;
    logic [7:0]  y_a, cb_a, cr_a;   // first pixel of the current pair
    logic [63:0] in_cnt, out_cnt;

    // pair chroma of THIS line (horizontal average)
    wire [7:0] cb_pair_now = (cb_a + Cb) >> 1;
    wire [7:0] cr_pair_now = (cr_a + Cr) >> 1;
    // vertical average with the stored even line
    wire [7:0] cb_final = (ch_line[x[10:1]][15:8] + cb_pair_now) >> 1;
    wire [7:0] cr_final = (ch_line[x[10:1]][7:0]  + cr_pair_now) >> 1;

    assign s_axis_video_tready = !m_axis_video_tvalid;
    assign m_axis_video_tlast  = 1'b0;
    assign in_beats  = in_cnt;
    assign out_beats = out_cnt;

    logic out_reg_free;
    assign out_reg_free = !m_axis_video_tvalid || (m_axis_video_tvalid && m_axis_video_tready);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            x <= '0;
            even_line <= 1'b1;
            sof_pending <= 1'b0;
            out_beat1 <= 1'b0;
            y_a <= '0; cb_a <= '0; cr_a <= '0;
            m_axis_video_tvalid <= 1'b0;
            m_axis_video_tdata  <= '0;
            m_axis_video_tuser  <= 1'b0;
            in_cnt <= '0;
            out_cnt <= '0;
        end else begin
            // ---- output: accept handshake / emit queued beat1 ----
            if (m_axis_video_tvalid && m_axis_video_tready) begin
                m_axis_video_tvalid <= 1'b0;
                out_cnt <= out_cnt + 1'b1;
            end
            if (out_reg_free && out_beat1) begin
                m_axis_video_tdata  <= beat1_reg;
                m_axis_video_tvalid <= 1'b1;
                m_axis_video_tuser  <= 1'b0;
                out_beat1 <= 1'b0;
            end

            // ---- input: consume when the output path has both slots free ----
            if (s_axis_video_tvalid && s_axis_video_tready && !out_beat1) begin
                in_cnt <= in_cnt + 1'b1;
                if (s_axis_video_tuser) begin
                    x <= '0;
                    even_line <= 1'b1;
                    sof_pending <= 1'b1;
                end

                if (even_line) begin
                    // Store phase: full-res Y + horizontal pair chroma.
                    y_line[x] <= Y;
                    if (x[0]) ch_line[x[10:1]] <= {cb_pair_now, cr_pair_now};
                end else begin
                    // Emit phase.
                    if (!x[0]) begin
                        // First pixel of the pair: latch, no output.
                        y_a <= Y; cb_a <= Cb; cr_a <= Cr;
                    end else begin
                        // Second pixel: beat0 now, beat1 queued.
                        m_axis_video_tdata <= {y_line[x-1], y_line[x], cb_final};
                        m_axis_video_tvalid <= 1'b1;
                        m_axis_video_tuser  <= sof_pending;
                        sof_pending <= 1'b0;
                        beat1_reg <= {y_a, Y, cr_final};
                        out_beat1 <= 1'b1;
                    end
                end

                if (x == 11'd1279) begin
                    x <= '0;
                    even_line <= ~even_line;
                end else begin
                    x <= x + 1'b1;
                end
            end
        end
    end
endmodule
