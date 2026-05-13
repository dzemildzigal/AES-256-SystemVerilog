`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite control plane for phase-1 ping-pong frame handoff.
//
// This module now supports two producer modes:
//   - Synthetic cadence mode (default): control-plane-only smoke behavior.
//   - Deterministic writer mode: AXI4 master burst writes into DDR ping-pong
//     buffers, then publishes READY/FRAME_ID/VALID_BYTES on completion.
//
// Register map (32-bit words):
//   0x0000 VERSION            RO
//   0x0004 CONTROL            RW    [0] enable [1] soft_reset_pulse
//   0x0008 STATUS             RO    [0] running [1] fault
//   0x0010 FRAME_BYTES_CFG    RW
//   0x0014 WRITE_INDEX        RO    [0] next producer buffer index
//   0x0018 READY_MASK         RO    [1:0] buffer readiness
//   0x001C CONSUMED_MASK      RW1C  (write 1 to mark consumed)
//   0x0020 FRAME_ID_BUF0      RO
//   0x0024 FRAME_ID_BUF1      RO
//   0x0028 VALID_BYTES_BUF0   RO
//   0x002C VALID_BYTES_BUF1   RO
//   0x0030 DROP_COUNT         RO
//   0x0034 IRQ_ENABLE         RW    [0]
//   0x0038 IRQ_STATUS         RW1C  [0]
//   0x0040 WRITER_ENABLE      RW    [0] deterministic AXI writer mode enable
//   0x0044 BUF0_ADDR_LO       RW
//   0x0048 BUF0_ADDR_HI       RW
//   0x004C BUF1_ADDR_LO       RW
//   0x0050 BUF1_ADDR_HI       RW
//   0x0054 WRITER_STATUS      RO    [0] busy [1] fault [2] writer_enable
//   0x0058 WRITER_ERROR_COUNT RO
//   0x005C WRITER_CMD         RW1C  [0] clear_fault [1] clear_error_count
//////////////////////////////////////////////////////////////////////////////////

module AXI_PingPong_Ctrl #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8,
    parameter [31:0] VERSION_VALUE = 32'h0001_0000,
    parameter [31:0] FRAME_BYTES_DEFAULT = 32'd6220800,
    parameter [31:0] FRAME_PERIOD_CYCLES = 32'd6666667,
    parameter integer WRITER_MAX_BURST_BEATS = 16
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

    // AXI4 master write path for deterministic DDR writer mode
    output wire [31:0]                         M_AXI_AWADDR,
    output wire [7:0]                          M_AXI_AWLEN,
    output wire [2:0]                          M_AXI_AWSIZE,
    output wire [1:0]                          M_AXI_AWBURST,
    output wire                                M_AXI_AWVALID,
    input  wire                                M_AXI_AWREADY,
    output wire [63:0]                         M_AXI_WDATA,
    output wire [7:0]                          M_AXI_WSTRB,
    output wire                                M_AXI_WLAST,
    output wire                                M_AXI_WVALID,
    input  wire                                M_AXI_WREADY,
    input  wire [1:0]                          M_AXI_BRESP,
    input  wire                                M_AXI_BVALID,
    output wire                                M_AXI_BREADY,

    output wire                                irq
);

    wire clk = S_AXI_ACLK;
    wire rst_axi = ~S_AXI_ARESETN;

    localparam [31:0] WRITER_MAX_BURST_BYTES_U32 = WRITER_MAX_BURST_BEATS * 8;

    localparam [2:0] WR_IDLE     = 3'd0;
    localparam [2:0] WR_PREP     = 3'd1;
    localparam [2:0] WR_AW       = 3'd2;
    localparam [2:0] WR_W        = 3'd3;
    localparam [2:0] WR_B        = 3'd4;
    localparam [2:0] WR_COMPLETE = 3'd5;
    localparam [2:0] WR_ERROR    = 3'd6;

    // AXI-Lite handshake registers
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

    // AXI master write channel registers
    reg [31:0] m_axi_awaddr;
    reg [7:0]  m_axi_awlen;
    reg        m_axi_awvalid;
    reg [63:0] m_axi_wdata;
    reg [7:0]  m_axi_wstrb;
    reg        m_axi_wlast;
    reg        m_axi_wvalid;
    reg        m_axi_bready;

    assign M_AXI_AWADDR  = m_axi_awaddr;
    assign M_AXI_AWLEN   = m_axi_awlen;
    assign M_AXI_AWSIZE  = 3'b011;  // 8-byte beats on 64-bit data bus
    assign M_AXI_AWBURST = 2'b01;   // INCR burst
    assign M_AXI_AWVALID = m_axi_awvalid;
    assign M_AXI_WDATA   = m_axi_wdata;
    assign M_AXI_WSTRB   = m_axi_wstrb;
    assign M_AXI_WLAST   = m_axi_wlast;
    assign M_AXI_WVALID  = m_axi_wvalid;
    assign M_AXI_BREADY  = m_axi_bready;

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

    // Deterministic writer configuration/status
    reg         writer_enable;
    reg [63:0]  buf0_base_addr;
    reg [63:0]  buf1_base_addr;
    reg         writer_busy;
    reg         writer_fault;
    reg [31:0]  writer_error_count;

    // Producer/writer internal state
    reg [31:0]  producer_frame_id;
    reg [31:0]  frame_period_counter;

    reg [2:0]   writer_state;
    reg         writer_target_index;
    reg [31:0]  writer_addr_curr;
    reg [31:0]  writer_bytes_remaining;
    reg [31:0]  writer_frame_bytes;
    reg [31:0]  writer_word_index;
    reg [31:0]  burst_bytes_total;
    reg [7:0]   burst_beats_total;
    reg [7:0]   burst_beats_sent;
    reg [7:0]   burst_last_strobe;

    wire [31:0] active_frame_bytes =
        (frame_bytes_cfg != 32'd0) ? frame_bytes_cfg : FRAME_BYTES_DEFAULT;

    wire wr_handshake = axi_awready && S_AXI_AWVALID
                     && axi_wready  && S_AXI_WVALID;

    wire [5:0] wr_index = axi_awaddr[7:2];
    wire [5:0] rd_index = axi_araddr[7:2];

    wire [63:0] selected_base_addr = write_index ? buf1_base_addr : buf0_base_addr;
    wire writer_base_invalid =
        (selected_base_addr[63:32] != 32'd0) ||
        (selected_base_addr[31:0] == 32'd0);

    wire [31:0] prep_burst_bytes =
        (writer_bytes_remaining > WRITER_MAX_BURST_BYTES_U32)
            ? WRITER_MAX_BURST_BYTES_U32
            : writer_bytes_remaining;

    wire [7:0] prep_burst_beats =
        (prep_burst_bytes[2:0] == 3'd0)
            ? prep_burst_bytes[10:3]
            : (prep_burst_bytes[10:3] + 8'd1);

    assign irq = irq_enable_reg[0] & irq_status_reg[0];

    function automatic [7:0] strobe_mask;
        input [2:0] byte_count;
        begin
            case (byte_count)
                3'd0: strobe_mask = 8'hFF;
                3'd1: strobe_mask = 8'h01;
                3'd2: strobe_mask = 8'h03;
                3'd3: strobe_mask = 8'h07;
                3'd4: strobe_mask = 8'h0F;
                3'd5: strobe_mask = 8'h1F;
                3'd6: strobe_mask = 8'h3F;
                3'd7: strobe_mask = 8'h7F;
                default: strobe_mask = 8'hFF;
            endcase
        end
    endfunction

    function automatic [63:0] pattern_word;
        input [31:0] frame_id;
        input [31:0] word_index;
        begin
            pattern_word = {frame_id, word_index};
        end
    endfunction

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

    // AXI-Lite write response
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

    // Contract register writes + producer logic
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            control_enable         <= 1'b0;
            frame_bytes_cfg        <= FRAME_BYTES_DEFAULT;
            write_index            <= 1'b0;
            ready_mask             <= 2'b00;
            frame_id_buf0          <= 32'd0;
            frame_id_buf1          <= 32'd0;
            valid_bytes_buf0       <= 32'd0;
            valid_bytes_buf1       <= 32'd0;
            drop_count             <= 32'd0;
            irq_enable_reg         <= 32'd0;
            irq_status_reg         <= 32'd0;

            writer_enable          <= 1'b0;
            buf0_base_addr         <= 64'd0;
            buf1_base_addr         <= 64'd0;
            writer_busy            <= 1'b0;
            writer_fault           <= 1'b0;
            writer_error_count     <= 32'd0;

            producer_frame_id      <= 32'd0;
            frame_period_counter   <= 32'd0;

            writer_state           <= WR_IDLE;
            writer_target_index    <= 1'b0;
            writer_addr_curr       <= 32'd0;
            writer_bytes_remaining <= 32'd0;
            writer_frame_bytes     <= 32'd0;
            writer_word_index      <= 32'd0;
            burst_bytes_total      <= 32'd0;
            burst_beats_total      <= 8'd0;
            burst_beats_sent       <= 8'd0;
            burst_last_strobe      <= 8'hFF;

            m_axi_awaddr           <= 32'd0;
            m_axi_awlen            <= 8'd0;
            m_axi_awvalid          <= 1'b0;
            m_axi_wdata            <= 64'd0;
            m_axi_wstrb            <= 8'hFF;
            m_axi_wlast            <= 1'b0;
            m_axi_wvalid           <= 1'b0;
            m_axi_bready           <= 1'b0;
        end
        else begin
            // AXI-Lite write side effects
            if (wr_handshake) begin
                case (wr_index)
                    6'd1: begin // CONTROL
                        control_enable <= S_AXI_WDATA[0];

                        if (S_AXI_WDATA[1]) begin // soft reset pulse
                            write_index            <= 1'b0;
                            ready_mask             <= 2'b00;
                            frame_id_buf0          <= 32'd0;
                            frame_id_buf1          <= 32'd0;
                            valid_bytes_buf0       <= 32'd0;
                            valid_bytes_buf1       <= 32'd0;
                            drop_count             <= 32'd0;
                            irq_status_reg         <= 32'd0;
                            producer_frame_id      <= 32'd0;
                            frame_period_counter   <= 32'd0;

                            writer_busy            <= 1'b0;
                            writer_fault           <= 1'b0;
                            writer_error_count     <= 32'd0;
                            writer_state           <= WR_IDLE;
                            writer_target_index    <= 1'b0;
                            writer_addr_curr       <= 32'd0;
                            writer_bytes_remaining <= 32'd0;
                            writer_frame_bytes     <= 32'd0;
                            writer_word_index      <= 32'd0;
                            burst_bytes_total      <= 32'd0;
                            burst_beats_total      <= 8'd0;
                            burst_beats_sent       <= 8'd0;
                            burst_last_strobe      <= 8'hFF;

                            m_axi_awaddr           <= 32'd0;
                            m_axi_awlen            <= 8'd0;
                            m_axi_awvalid          <= 1'b0;
                            m_axi_wdata            <= 64'd0;
                            m_axi_wstrb            <= 8'hFF;
                            m_axi_wlast            <= 1'b0;
                            m_axi_wvalid           <= 1'b0;
                            m_axi_bready           <= 1'b0;
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

                    6'd16: begin // WRITER_ENABLE
                        writer_enable <= S_AXI_WDATA[0];
                    end

                    6'd17: begin // BUF0_ADDR_LO
                        buf0_base_addr[31:0] <= S_AXI_WDATA;
                    end

                    6'd18: begin // BUF0_ADDR_HI
                        buf0_base_addr[63:32] <= S_AXI_WDATA;
                    end

                    6'd19: begin // BUF1_ADDR_LO
                        buf1_base_addr[31:0] <= S_AXI_WDATA;
                    end

                    6'd20: begin // BUF1_ADDR_HI
                        buf1_base_addr[63:32] <= S_AXI_WDATA;
                    end

                    6'd23: begin // WRITER_CMD (RW1C)
                        writer_fault       <= writer_fault & ~S_AXI_WDATA[0];
                        if (S_AXI_WDATA[1]) begin
                            writer_error_count <= 32'd0;
                        end
                    end

                    default: begin
                        // no-op
                    end
                endcase
            end

            if (control_enable) begin
                if (writer_enable) begin
                    frame_period_counter <= 32'd0;

                    case (writer_state)
                        WR_IDLE: begin
                            if ((write_index == 1'b0 && ready_mask[0]) ||
                                (write_index == 1'b1 && ready_mask[1])) begin
                                drop_count <= drop_count + 32'd1;
                            end
                            else if (writer_base_invalid) begin
                                writer_fault       <= 1'b1;
                                writer_error_count <= writer_error_count + 32'd1;
                                writer_busy        <= 1'b0;
                                writer_state       <= WR_ERROR;
                            end
                            else begin
                                writer_target_index    <= write_index;
                                writer_addr_curr       <= selected_base_addr[31:0];
                                writer_frame_bytes     <= active_frame_bytes;
                                writer_bytes_remaining <= active_frame_bytes;
                                writer_word_index      <= 32'd0;
                                writer_busy            <= 1'b1;
                                writer_state           <= WR_PREP;
                            end
                        end

                        WR_PREP: begin
                            if (writer_bytes_remaining == 32'd0) begin
                                writer_state <= WR_COMPLETE;
                            end
                            else begin
                                burst_bytes_total <= prep_burst_bytes;
                                burst_beats_total <= prep_burst_beats;
                                burst_beats_sent  <= 8'd0;
                                burst_last_strobe <= strobe_mask(prep_burst_bytes[2:0]);

                                m_axi_awaddr  <= writer_addr_curr;
                                m_axi_awlen   <= prep_burst_beats - 8'd1;
                                m_axi_awvalid <= 1'b1;

                                writer_state <= WR_AW;
                            end
                        end

                        WR_AW: begin
                            if (m_axi_awvalid && M_AXI_AWREADY) begin
                                m_axi_awvalid <= 1'b0;
                                m_axi_wvalid  <= 1'b1;
                                m_axi_wdata   <= pattern_word(producer_frame_id, writer_word_index);

                                if (burst_beats_total == 8'd1) begin
                                    m_axi_wlast <= 1'b1;
                                    m_axi_wstrb <= burst_last_strobe;
                                end
                                else begin
                                    m_axi_wlast <= 1'b0;
                                    m_axi_wstrb <= 8'hFF;
                                end

                                writer_state <= WR_W;
                            end
                        end

                        WR_W: begin
                            if (m_axi_wvalid && M_AXI_WREADY) begin
                                writer_addr_curr  <= writer_addr_curr + 32'd8;
                                writer_word_index <= writer_word_index + 32'd1;

                                if ((burst_beats_sent + 8'd1) >= burst_beats_total) begin
                                    m_axi_wvalid <= 1'b0;
                                    m_axi_wlast  <= 1'b0;
                                    m_axi_wstrb  <= 8'hFF;
                                    m_axi_bready <= 1'b1;
                                    writer_state <= WR_B;
                                end
                                else begin
                                    burst_beats_sent <= burst_beats_sent + 8'd1;
                                    m_axi_wdata      <= pattern_word(producer_frame_id, writer_word_index + 32'd1);

                                    if ((burst_beats_sent + 8'd2) >= burst_beats_total) begin
                                        m_axi_wlast <= 1'b1;
                                        m_axi_wstrb <= burst_last_strobe;
                                    end
                                    else begin
                                        m_axi_wlast <= 1'b0;
                                        m_axi_wstrb <= 8'hFF;
                                    end
                                end
                            end
                        end

                        WR_B: begin
                            if (M_AXI_BVALID && m_axi_bready) begin
                                m_axi_bready <= 1'b0;

                                if (M_AXI_BRESP != 2'b00) begin
                                    writer_fault       <= 1'b1;
                                    writer_error_count <= writer_error_count + 32'd1;
                                    writer_busy        <= 1'b0;
                                    writer_state       <= WR_ERROR;
                                end
                                else if (writer_bytes_remaining > burst_bytes_total) begin
                                    writer_bytes_remaining <= writer_bytes_remaining - burst_bytes_total;
                                    writer_state           <= WR_PREP;
                                end
                                else begin
                                    writer_bytes_remaining <= 32'd0;
                                    writer_state           <= WR_COMPLETE;
                                end
                            end
                        end

                        WR_COMPLETE: begin
                            writer_busy <= 1'b0;

                            if (writer_target_index == 1'b0) begin
                                frame_id_buf0    <= producer_frame_id;
                                valid_bytes_buf0 <= writer_frame_bytes;
                                ready_mask[0]    <= 1'b1;
                            end
                            else begin
                                frame_id_buf1    <= producer_frame_id;
                                valid_bytes_buf1 <= writer_frame_bytes;
                                ready_mask[1]    <= 1'b1;
                            end

                            producer_frame_id <= producer_frame_id + 32'd1;
                            write_index       <= ~writer_target_index;

                            if (irq_enable_reg[0]) begin
                                irq_status_reg[0] <= 1'b1;
                            end

                            writer_state <= WR_IDLE;
                        end

                        WR_ERROR: begin
                            writer_busy <= 1'b0;
                            m_axi_awvalid <= 1'b0;
                            m_axi_wvalid  <= 1'b0;
                            m_axi_bready  <= 1'b0;
                            m_axi_wlast   <= 1'b0;
                            m_axi_wstrb   <= 8'hFF;

                            if (!writer_fault) begin
                                writer_state <= WR_IDLE;
                            end
                        end

                        default: begin
                            writer_state <= WR_IDLE;
                        end
                    endcase
                end
                else begin
                    // Synthetic producer cadence for control-plane bring-up.
                    // Deterministic writer mode is enabled via WRITER_ENABLE.
                    writer_state <= WR_IDLE;
                    writer_busy  <= 1'b0;
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_bready  <= 1'b0;
                    m_axi_wlast   <= 1'b0;
                    m_axi_wstrb   <= 8'hFF;

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
            end
            else begin
                frame_period_counter <= 32'd0;
                writer_state <= WR_IDLE;
                writer_busy  <= 1'b0;
                m_axi_awvalid <= 1'b0;
                m_axi_wvalid  <= 1'b0;
                m_axi_bready  <= 1'b0;
                m_axi_wlast   <= 1'b0;
                m_axi_wstrb   <= 8'hFF;
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
            6'd0:  rd_mux = VERSION_VALUE;                                            // 0x00
            6'd1:  rd_mux = {30'd0, 1'b0, control_enable};                            // 0x04
            6'd2:  rd_mux = {30'd0, writer_fault, control_enable};                    // 0x08
            6'd4:  rd_mux = frame_bytes_cfg;                                          // 0x10
            6'd5:  rd_mux = {31'd0, write_index};                                     // 0x14
            6'd6:  rd_mux = {30'd0, ready_mask};                                      // 0x18
            6'd7:  rd_mux = 32'd0;                                                    // 0x1C command register
            6'd8:  rd_mux = frame_id_buf0;                                            // 0x20
            6'd9:  rd_mux = frame_id_buf1;                                            // 0x24
            6'd10: rd_mux = valid_bytes_buf0;                                         // 0x28
            6'd11: rd_mux = valid_bytes_buf1;                                         // 0x2C
            6'd12: rd_mux = drop_count;                                               // 0x30
            6'd13: rd_mux = irq_enable_reg;                                           // 0x34
            6'd14: rd_mux = irq_status_reg;                                           // 0x38
            6'd16: rd_mux = {31'd0, writer_enable};                                   // 0x40
            6'd17: rd_mux = buf0_base_addr[31:0];                                     // 0x44
            6'd18: rd_mux = buf0_base_addr[63:32];                                    // 0x48
            6'd19: rd_mux = buf1_base_addr[31:0];                                     // 0x4C
            6'd20: rd_mux = buf1_base_addr[63:32];                                    // 0x50
            6'd21: rd_mux = {29'd0, writer_enable, writer_fault, writer_busy};        // 0x54
            6'd22: rd_mux = writer_error_count;                                       // 0x58
            6'd23: rd_mux = 32'd0;                                                    // 0x5C command register
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
