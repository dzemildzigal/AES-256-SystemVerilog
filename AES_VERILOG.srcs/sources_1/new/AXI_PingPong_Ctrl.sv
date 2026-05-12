`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite control plane for phase-1 ping-pong frame handoff.
//
// This module implements the map0 register contract in
// pynq/ping_pong_frame_contract.md and provides a synthetic producer cadence
// so ownership logic can be validated before full frame-capture/DDR-writer
// integration.
//
// Register map (32-bit words):
//   0x0000 VERSION          RO
//   0x0004 CONTROL          RW  [0] enable [1] soft_reset_pulse
//   0x0008 STATUS           RO  [0] running [1] fault
//   0x0010 FRAME_BYTES_CFG  RW
//   0x0014 WRITE_INDEX      RO  [0] next producer buffer index
//   0x0018 READY_MASK       RO  [1:0] buffer readiness
//   0x001C CONSUMED_MASK    RW1C (write 1 to mark consumed)
//   0x0020 FRAME_ID_BUF0    RO
//   0x0024 FRAME_ID_BUF1    RO
//   0x0028 VALID_BYTES_BUF0 RO
//   0x002C VALID_BYTES_BUF1 RO
//   0x0030 DROP_COUNT       RO
//   0x0034 IRQ_ENABLE       RW  [0]
//   0x0038 IRQ_STATUS       RW1C [0]
//////////////////////////////////////////////////////////////////////////////////

module AXI_PingPong_Ctrl #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8,
    parameter [31:0] VERSION_VALUE = 32'h0001_0000,
    parameter [31:0] FRAME_BYTES_DEFAULT = 32'd6220800,
    parameter [31:0] FRAME_PERIOD_CYCLES = 32'd6666667
)(
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire [2:0]                          S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    // Write response channel
    output wire [1:0]                          S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire [2:0]                          S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output wire [1:0]                          S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY,

    output wire                                irq
);

    wire clk = S_AXI_ACLK;
    wire rst_axi = ~S_AXI_ARESETN;

    // AXI handshake registers
    reg                            axi_awready;
    reg                            axi_wready;
    reg [1:0]                      axi_bresp;
    reg                            axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0]   axi_awaddr;
    reg                            axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0]   axi_rdata;
    reg [1:0]                      axi_rresp;
    reg                            axi_rvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0]   axi_araddr;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // Contract registers
    reg         control_enable;
    reg [31:0]  frame_bytes_cfg;
    reg         write_index;
    reg [1:0]   ready_mask;
    reg [31:0]  frame_id_buf0;
    reg [31:0]  frame_id_buf1;
    reg [31:0]  valid_bytes_buf0;
    reg [31:0]  valid_bytes_buf1;
    reg [31:0]  drop_count;
    reg [31:0]  irq_enable_reg;
    reg [31:0]  irq_status_reg;

    // Internal producer state
    reg [31:0]  producer_frame_id;
    reg [31:0]  frame_period_counter;

    wire [31:0] active_frame_bytes =
        (frame_bytes_cfg != 32'd0) ? frame_bytes_cfg : FRAME_BYTES_DEFAULT;

    wire wr_handshake = axi_awready && S_AXI_AWVALID
                     && axi_wready  && S_AXI_WVALID;

    wire [5:0] wr_index = axi_awaddr[7:2];
    wire [5:0] rd_index = axi_araddr[7:2];

    assign irq = irq_enable_reg[0] & irq_status_reg[0];

    // AXI Write Address + Data (accept together)
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_awaddr  <= '0;
        end
        else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && (~axi_bvalid || S_AXI_BREADY)) begin
            axi_awready <= 1'b1;
            axi_wready  <= 1'b1;
            axi_awaddr  <= S_AXI_AWADDR;
        end
        else begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
        end
    end

    // Write response
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end
        else if (wr_handshake && ~axi_bvalid) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;
        end
        else if (S_AXI_BREADY && axi_bvalid) begin
            axi_bvalid <= 1'b0;
        end
    end

    // Contract register writes + synthetic producer logic
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            control_enable       <= 1'b0;
            frame_bytes_cfg      <= FRAME_BYTES_DEFAULT;
            write_index          <= 1'b0;
            ready_mask           <= 2'b00;
            frame_id_buf0        <= 32'd0;
            frame_id_buf1        <= 32'd0;
            valid_bytes_buf0     <= 32'd0;
            valid_bytes_buf1     <= 32'd0;
            drop_count           <= 32'd0;
            irq_enable_reg       <= 32'd0;
            irq_status_reg       <= 32'd0;
            producer_frame_id    <= 32'd0;
            frame_period_counter <= 32'd0;
        end
        else begin
            // AXI write side effects
            if (wr_handshake) begin
                case (wr_index)
                    6'd1: begin // CONTROL
                        control_enable <= S_AXI_WDATA[0];

                        if (S_AXI_WDATA[1]) begin // soft reset pulse
                            write_index          <= 1'b0;
                            ready_mask           <= 2'b00;
                            frame_id_buf0        <= 32'd0;
                            frame_id_buf1        <= 32'd0;
                            valid_bytes_buf0     <= 32'd0;
                            valid_bytes_buf1     <= 32'd0;
                            drop_count           <= 32'd0;
                            irq_status_reg       <= 32'd0;
                            producer_frame_id    <= 32'd0;
                            frame_period_counter <= 32'd0;
                        end
                    end

                    6'd4: begin // FRAME_BYTES_CFG
                        frame_bytes_cfg <= S_AXI_WDATA;
                    end

                    6'd7: begin // CONSUMED_MASK (RW1C command)
                        ready_mask <= ready_mask & ~S_AXI_WDATA[1:0];
                    end

                    6'd13: begin // IRQ_ENABLE
                        irq_enable_reg <= S_AXI_WDATA;
                    end

                    6'd14: begin // IRQ_STATUS (RW1C)
                        irq_status_reg <= irq_status_reg & ~S_AXI_WDATA;
                    end

                    default: begin
                        // no-op
                    end
                endcase
            end

            // Synthetic producer cadence for control-plane bring-up.
            // Full frame-capture + DDR writer datapath will replace this section.
            if (control_enable) begin
                if (frame_period_counter >= (FRAME_PERIOD_CYCLES - 32'd1)) begin
                    frame_period_counter <= 32'd0;

                    if ((write_index == 1'b0 && ready_mask[0]) ||
                        (write_index == 1'b1 && ready_mask[1])) begin
                        drop_count <= drop_count + 32'd1;
                    end
                    else begin
                        if (write_index == 1'b0) begin
                            frame_id_buf0    <= producer_frame_id;
                            valid_bytes_buf0 <= active_frame_bytes;
                            ready_mask[0]    <= 1'b1;
                        end
                        else begin
                            frame_id_buf1    <= producer_frame_id;
                            valid_bytes_buf1 <= active_frame_bytes;
                            ready_mask[1]    <= 1'b1;
                        end

                        producer_frame_id <= producer_frame_id + 32'd1;
                        write_index <= ~write_index;

                        if (irq_enable_reg[0]) begin
                            irq_status_reg[0] <= 1'b1;
                        end
                    end
                end
                else begin
                    frame_period_counter <= frame_period_counter + 32'd1;
                end
            end
            else begin
                frame_period_counter <= 32'd0;
            end
        end
    end

    // AXI Read Address
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            axi_arready <= 1'b0;
            axi_araddr  <= '0;
        end
        else if (~axi_arready && S_AXI_ARVALID) begin
            axi_arready <= 1'b1;
            axi_araddr  <= S_AXI_ARADDR;
        end
        else begin
            axi_arready <= 1'b0;
        end
    end

    // Read mux
    reg [C_S_AXI_DATA_WIDTH-1:0] rd_mux;

    always_comb begin
        case (rd_index)
            6'd0:  rd_mux = VERSION_VALUE;                                        // 0x00
            6'd1:  rd_mux = {30'd0, 1'b0, control_enable};                        // 0x04
            6'd2:  rd_mux = {30'd0, 1'b0, control_enable};                        // 0x08 (fault=0)
            6'd4:  rd_mux = frame_bytes_cfg;                                      // 0x10
            6'd5:  rd_mux = {31'd0, write_index};                                 // 0x14
            6'd6:  rd_mux = {30'd0, ready_mask};                                  // 0x18
            6'd7:  rd_mux = 32'd0;                                                // 0x1C command register
            6'd8:  rd_mux = frame_id_buf0;                                        // 0x20
            6'd9:  rd_mux = frame_id_buf1;                                        // 0x24
            6'd10: rd_mux = valid_bytes_buf0;                                     // 0x28
            6'd11: rd_mux = valid_bytes_buf1;                                     // 0x2C
            6'd12: rd_mux = drop_count;                                           // 0x30
            6'd13: rd_mux = irq_enable_reg;                                       // 0x34
            6'd14: rd_mux = irq_status_reg;                                       // 0x38
            default: rd_mux = 32'd0;
        endcase
    end

    // Read response
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
            axi_rdata  <= '0;
        end
        else if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b00;
            axi_rdata  <= rd_mux;
        end
        else if (axi_rvalid && S_AXI_RREADY) begin
            axi_rvalid <= 1'b0;
        end
    end

endmodule
