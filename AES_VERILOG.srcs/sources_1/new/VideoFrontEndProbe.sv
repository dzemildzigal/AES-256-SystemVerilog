`timescale 1ns / 1ps
// Inline passthrough probe between color_swap pixel_output and v_vid_in
// vid_io_in. Counts recovered PixelClk cycles (pixel_clk_count) and
// active-video DE pixels (de_count), passing every vid_io signal straight
// through so the real video path is never broken.
module VideoFrontEndProbe (
    input  wire         vid_clk,

    input  wire [23:0]  vid_io_in_DATA,
    input  wire         vid_io_in_ACTIVE_VIDEO,
    input  wire         vid_io_in_HSYNC,
    input  wire         vid_io_in_VSYNC,
    // v_vid_in coupler overflow pulse, synchronous to vid_clk (PG043).
    input  wire         vid_overflow,

    output wire [23:0]  vid_io_out_DATA,
    output wire         vid_io_out_ACTIVE_VIDEO,
    output wire         vid_io_out_HSYNC,
    output wire         vid_io_out_VSYNC,

    output reg  [63:0]  pixel_clk_count,
    output reg  [63:0]  de_count,
    output reg  [31:0]  de_at_overflow
);
    assign vid_io_out_DATA         = vid_io_in_DATA;
    assign vid_io_out_ACTIVE_VIDEO = vid_io_in_ACTIVE_VIDEO;
    assign vid_io_out_HSYNC        = vid_io_in_HSYNC;
    assign vid_io_out_VSYNC        = vid_io_in_VSYNC;

    reg overflow_d;
    always @(posedge vid_clk) begin
        pixel_clk_count <= pixel_clk_count + 1'b1;
        if (vid_io_in_ACTIVE_VIDEO)
            de_count <= de_count + 1'b1;
        overflow_d <= vid_overflow;
        if (vid_overflow && !overflow_d)
            de_at_overflow <= de_count[31:0];
    end
endmodule
