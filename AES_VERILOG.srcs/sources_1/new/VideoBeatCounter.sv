`timescale 1ns / 1ps
// Tiny free-running probe counter: counts tvalid beats of v_vid_in_axi4s's
// video_out stream (pre-CDC-FIFO). Exposed read-only via aes_seq_0 so
// software can bisect where the video data path dies:
//   prefifo_beats > 0 && packetizer beats == 0  -> CDC FIFO (read side) is
//                                                   the problem
//   prefifo_beats == 0                          -> v_vid_in_axi4s never
//                                                   produces a valid beat
// Clocked in the 142 MHz video AXI domain (same as the counted signal).
module VideoBeatCounter (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        s_axis_video_tvalid,
    output logic [63:0] count
);
    logic [63:0] cnt_r;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            cnt_r <= '0;
        end else if (s_axis_video_tvalid) begin
            cnt_r <= cnt_r + 1'b1;
        end
    end

    assign count = cnt_r;
endmodule
