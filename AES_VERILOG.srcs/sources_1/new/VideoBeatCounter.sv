`timescale 1ns / 1ps
// Inline passthrough probe: sits between v_vid_in_axi4s's video_out and the
// CDC FIFO, counts accepted video beats, and passes every signal straight
// through so the real video path is never broken.
module VideoBeatCounter (
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

    output logic [63:0]  count
);
    assign m_axis_video_tdata  = s_axis_video_tdata;
    assign m_axis_video_tvalid = s_axis_video_tvalid;
    assign m_axis_video_tlast  = s_axis_video_tlast;
    assign m_axis_video_tuser  = s_axis_video_tuser;
    assign s_axis_video_tready = m_axis_video_tready;

    logic [63:0] cnt_r;
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            cnt_r <= '0;
        end else if (s_axis_video_tvalid && s_axis_video_tready) begin
            cnt_r <= cnt_r + 1'b1;
        end
    end

    assign count = cnt_r;
endmodule
