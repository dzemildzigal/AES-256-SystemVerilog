`timescale 1ns / 1ps
// Verilog wrapper for AXI_AES_GCM_Stream (SystemVerilog).
// Vivado block-design module references require a plain .v top file.

module AXI_AES_GCM_Stream_wrapper #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8
)(
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire [2:0]                          S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    output wire [1:0]                          S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire [2:0]                          S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output wire [1:0]                          S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY,

    input  wire [127:0]                        S_AXIS_PT_TDATA,
    input  wire [15:0]                         S_AXIS_PT_TKEEP,
    input  wire                                S_AXIS_PT_TLAST,
    input  wire                                S_AXIS_PT_TVALID,
    output wire                                S_AXIS_PT_TREADY,

    output wire [127:0]                        M_AXIS_CT_TDATA,
    output wire [15:0]                         M_AXIS_CT_TKEEP,
    output wire                                M_AXIS_CT_TLAST,
    output wire                                M_AXIS_CT_TVALID,
    input  wire                                M_AXIS_CT_TREADY
);

    AXI_AES_GCM_Stream #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_axi_gcm_stream (
        .S_AXI_ACLK    (S_AXI_ACLK),
        .S_AXI_ARESETN (S_AXI_ARESETN),
        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),
        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),
        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),
        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),
        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY),

        .S_AXIS_PT_TDATA  (S_AXIS_PT_TDATA),
        .S_AXIS_PT_TKEEP  (S_AXIS_PT_TKEEP),
        .S_AXIS_PT_TLAST  (S_AXIS_PT_TLAST),
        .S_AXIS_PT_TVALID (S_AXIS_PT_TVALID),
        .S_AXIS_PT_TREADY (S_AXIS_PT_TREADY),

        .M_AXIS_CT_TDATA  (M_AXIS_CT_TDATA),
        .M_AXIS_CT_TKEEP  (M_AXIS_CT_TKEEP),
        .M_AXIS_CT_TLAST  (M_AXIS_CT_TLAST),
        .M_AXIS_CT_TVALID (M_AXIS_CT_TVALID),
        .M_AXIS_CT_TREADY (M_AXIS_CT_TREADY)
    );

endmodule
