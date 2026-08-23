`timescale 1ns / 1ps
// Verilog wrapper for VideoFrontEndProbe (SystemVerilog).
// Vivado block-design module references require a plain .v top file.
module VideoFrontEndProbe_wrapper (
    input  wire         vid_clk,

    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_in DATA" *)
    input  wire [23:0]  vid_io_in_DATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_in ACTIVE_VIDEO" *)
    input  wire         vid_io_in_ACTIVE_VIDEO,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_in HSYNC" *)
    input  wire         vid_io_in_HSYNC,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_in VSYNC" *)
    input  wire         vid_io_in_VSYNC,

    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_out DATA" *)
    output wire [23:0]  vid_io_out_DATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_out ACTIVE_VIDEO" *)
    output wire         vid_io_out_ACTIVE_VIDEO,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_out HSYNC" *)
    output wire         vid_io_out_HSYNC,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 vid_io_out VSYNC" *)
    output wire         vid_io_out_VSYNC,

    output wire [63:0]  pixel_clk_count,
    output wire [63:0]  de_count
);

    VideoFrontEndProbe u_probe (
        .vid_clk               (vid_clk),
        .vid_io_in_DATA        (vid_io_in_DATA),
        .vid_io_in_ACTIVE_VIDEO(vid_io_in_ACTIVE_VIDEO),
        .vid_io_in_HSYNC       (vid_io_in_HSYNC),
        .vid_io_in_VSYNC       (vid_io_in_VSYNC),
        .vid_io_out_DATA       (vid_io_out_DATA),
        .vid_io_out_ACTIVE_VIDEO(vid_io_out_ACTIVE_VIDEO),
        .vid_io_out_HSYNC      (vid_io_out_HSYNC),
        .vid_io_out_VSYNC      (vid_io_out_VSYNC),
        .pixel_clk_count       (pixel_clk_count),
        .de_count              (de_count)
    );

endmodule
