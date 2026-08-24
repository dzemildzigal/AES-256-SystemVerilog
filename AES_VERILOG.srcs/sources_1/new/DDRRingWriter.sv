`timescale 1ns / 1ps

// DDRRingWriter
//
// Consumes the B.1 packet stream:
//   one 8-byte nonce-prefix beat (TKEEP=00FF), followed by
//   77 full 128-bit ciphertext/tag beats (TKEEP=FFFF).
//
// It stores one complete 1240-byte packet plus 40 explicit zero padding
// bytes in one 1280-byte DDR ring slot. The padding is transport padding:
// B.3 can send complete 1280-byte slots with UDP GSO without a PS gather
// copy. The padding is outside the GCM-protected 1240-byte body.
//
// The writer refreshes the PS consume index periodically and before a
// possible full-ring decision. If the ring is full, it drains the complete
// input packet without writing it and increments drop_count once. A
// successfully written slot is published by writing the new produce index to
// CTRL_BASE + 0 only after the final AXI B response.
module DDRRingWriter #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter [31:0] VERSION_VALUE = 32'h0002_0000,
    parameter integer PACKET_BYTES = 1240,
    parameter integer SLOT_STRIDE = 1280,
    parameter integer RING_LOG2 = 11
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

    // AXI4 master used for packet-slot writes and control-block accesses.
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
    output wire [31:0]                         M_AXI_ARADDR,
    output wire [2:0]                          M_AXI_ARPROT,
    output wire                                M_AXI_ARVALID,
    input  wire                                M_AXI_ARREADY,
    input  wire [31:0]                         M_AXI_RDATA,
    input  wire [1:0]                          M_AXI_RRESP,
    input  wire                                M_AXI_RVALID,
    output wire                                M_AXI_RREADY,

    input  wire [127:0]                        S_AXIS_TDATA,
    input  wire [15:0]                         S_AXIS_TKEEP,
    input  wire                                S_AXIS_TLAST,
    input  wire                                S_AXIS_TVALID,
    output wire                                S_AXIS_TREADY,

    output wire                                irq
);

    localparam integer PACKET_WORDS = PACKET_BYTES / 8;
    localparam integer SLOT_WORDS = SLOT_STRIDE / 8;
    localparam integer RING_SLOTS = (1 << RING_LOG2);

    localparam [3:0] ST_IDLE       = 4'd0;
    localparam [3:0] ST_CTRL_AR    = 4'd1;
    localparam [3:0] ST_CTRL_R     = 4'd2;
    localparam [3:0] ST_CAPTURE    = 4'd3;
    localparam [3:0] ST_DROP       = 4'd4;
    localparam [3:0] ST_PREP       = 4'd5;
    localparam [3:0] ST_AW         = 4'd6;
    localparam [3:0] ST_W          = 4'd7;
    localparam [3:0] ST_B          = 4'd8;
    localparam [3:0] ST_PUB_AW     = 4'd9;
    localparam [3:0] ST_PUB_W      = 4'd10;
    localparam [3:0] ST_PUB_B      = 4'd11;
    localparam [3:0] ST_ERROR      = 4'd12;

    localparam [31:0] FAULT_BASE    = 32'd1;
    localparam [31:0] FAULT_TKEEP   = 32'd2;
    localparam [31:0] FAULT_LENGTH  = 32'd3;
    localparam [31:0] FAULT_BRESP   = 32'd4;
    localparam [31:0] FAULT_CTRL_R  = 32'd5;
    localparam [31:0] FAULT_CTRL_W  = 32'd6;

    // AXI-Lite slave registers.
    reg                            axi_awready;
    reg                            axi_wready;
    reg [1:0]                      axi_bresp;
    reg                            axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0]   axi_awaddr;
    reg                            axi_arready;
    reg [31:0]                     axi_rdata;
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

    wire clk = S_AXI_ACLK;
    wire rst = ~S_AXI_ARESETN;
    wire wr_fire = axi_awready && S_AXI_AWVALID &&
                   axi_wready && S_AXI_WVALID;
    wire [5:0] wr_index = axi_awaddr[7:2];
    wire [5:0] rd_index = axi_araddr[7:2];

    reg         control_enable;
    reg [63:0]  ring_base_addr;
    reg [63:0]  ctrl_base_addr;
    reg [31:0]  ring_log2_reg;
    reg [31:0]  slot_stride_reg;
    reg [31:0]  produce_idx;
    reg [31:0]  consume_idx_shadow;
    // Refresh the PS-owned consume index periodically and whenever the
    // cached value says the ring may be full. This keeps the normal path
    // from paying one AXI read for every packet while retaining safe drops.
    reg [5:0]   consume_read_age;
    reg [31:0]  drop_count;
    reg [31:0]  error_count;
    reg [63:0]  complete_count;
    reg [31:0]  fault_code;
    reg         writer_fault;
    reg         writer_busy;
    reg [31:0]  irq_enable_reg;
    reg [31:0]  irq_status_reg;

    assign irq = irq_enable_reg[0] && irq_status_reg[0];

    // AXI master write channel.
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
    assign M_AXI_AWSIZE  = 3'b011;
    assign M_AXI_AWBURST = 2'b01;
    assign M_AXI_AWVALID = m_axi_awvalid;
    assign M_AXI_WDATA   = m_axi_wdata;
    assign M_AXI_WSTRB   = m_axi_wstrb;
    assign M_AXI_WLAST   = m_axi_wlast;
    assign M_AXI_WVALID  = m_axi_wvalid;
    assign M_AXI_BREADY  = m_axi_bready;

    // AXI master read channel. It reads CTRL_BASE+4 before each packet.
    reg [31:0] m_axi_araddr;
    reg        m_axi_arvalid;
    reg        m_axi_rready;

    assign M_AXI_ARADDR  = m_axi_araddr;
    assign M_AXI_ARPROT  = 3'b000;
    assign M_AXI_ARVALID = m_axi_arvalid;
    assign M_AXI_RREADY  = m_axi_rready;

    // One slot buffer. The input body is PACKET_WORDS words; the remaining
    // words are written as explicit zero transport padding.
    reg [63:0] packet_buf [0:SLOT_WORDS-1];
    reg [7:0]  capture_word_count;
    reg [10:0] burst_word_index;
    reg [4:0]  burst_word_count;
    reg [4:0]  burst_beats_sent;
    reg [10:0] target_slot;
    reg [10:0] next_produce_slot;
    reg [3:0]  writer_state;

    wire [31:0] ring_mask = RING_SLOTS - 1;
    wire consume_refresh = (consume_read_age >= 6'd31) ||
                           ((((produce_idx + 1'b1) & ring_mask) ==
                             (consume_idx_shadow & ring_mask)));
    wire publish_fire = (writer_state == ST_PUB_B) &&
                        M_AXI_BVALID && m_axi_bready &&
                        (M_AXI_BRESP == 2'b00);
    wire [31:0] ring_slot_addr = ring_base_addr[31:0] +
                                  (target_slot * slot_stride_reg);
    wire base_invalid = (ring_base_addr[63:32] != 0) ||
                         (ctrl_base_addr[63:32] != 0) ||
                         (ring_base_addr[31:0] == 0) ||
                         (ctrl_base_addr[31:0] == 0) ||
                         // Ten full 128-byte bursts per 1280-byte slot.
                         // A 128-byte-aligned base keeps every burst inside
                         // one 4 KiB AXI boundary.
                         (ring_base_addr[6:0] != 0);

    assign S_AXIS_TREADY = control_enable && !writer_fault &&
                           ((writer_state == ST_CAPTURE) ||
                            (writer_state == ST_DROP));

    // AXI-Lite write channel. Address and data are accepted together, as in
    // the existing control modules in this project.
    always @(posedge clk) begin
        if (rst) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_awaddr  <= 0;
        end else if (!axi_awready && S_AXI_AWVALID && S_AXI_WVALID &&
                     (!axi_bvalid || S_AXI_BREADY)) begin
            axi_awready <= 1'b1;
            axi_wready  <= 1'b1;
            axi_awaddr  <= S_AXI_AWADDR;
        end else begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else if (wr_fire && !axi_bvalid) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;
        end else if (axi_bvalid && S_AXI_BREADY) begin
            axi_bvalid <= 1'b0;
        end
    end

    // AXI-Lite control registers and read mux.
    always @(posedge clk) begin
        if (rst) begin
            control_enable    <= 1'b0;
            ring_base_addr    <= 64'd0;
            ctrl_base_addr    <= 64'd0;
            ring_log2_reg     <= RING_LOG2;
            slot_stride_reg   <= SLOT_STRIDE;
            irq_enable_reg    <= 32'd0;
            irq_status_reg    <= 32'd0;
            axi_arready       <= 1'b0;
            axi_rdata         <= 32'd0;
            axi_rresp         <= 2'b00;
            axi_rvalid        <= 1'b0;
            axi_araddr        <= '0;
        end else begin
            if (wr_fire) begin
                case (wr_index)
                    6'd1: begin
                        control_enable <= S_AXI_WDATA[0];
                        if (S_AXI_WDATA[1]) begin
                            control_enable <= 1'b0;
                            irq_status_reg <= 32'd0;
                        end
                    end
                    6'd3: ring_base_addr[31:0] <= S_AXI_WDATA;
                    6'd4: ring_base_addr[63:32] <= S_AXI_WDATA;
                    6'd5: ctrl_base_addr[31:0] <= S_AXI_WDATA;
                    6'd6: ctrl_base_addr[63:32] <= S_AXI_WDATA;
                    6'd9: irq_enable_reg <= S_AXI_WDATA;
                    default: begin end
                endcase
            end

            // Keep the IRQ status register in this single clocked block.
            // A successful publication sets bit 0; a PS write at 0x44
            // clears selected bits (RW1C). Publication wins if both happen
            // on one clock, so an event is never lost.
            if (publish_fire)
                irq_status_reg <= (irq_status_reg &
                                   ~((wr_fire && (wr_index == 6'd10)) ?
                                     S_AXI_WDATA : 32'd0)) | 32'd1;
            else if (wr_fire && (wr_index == 6'd10))
                irq_status_reg <= irq_status_reg & ~S_AXI_WDATA;

            if (!axi_arready && S_AXI_ARVALID &&
                (!axi_rvalid || S_AXI_RREADY)) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end

            if (axi_arready && S_AXI_ARVALID) begin
                case (rd_index)
                    6'd0:  axi_rdata <= VERSION_VALUE;
                    6'd1:  axi_rdata <= {30'd0, writer_fault, control_enable};
                    6'd2:  axi_rdata <= {29'd0, writer_busy, writer_fault, control_enable};
                    6'd3:  axi_rdata <= ring_base_addr[31:0];
                    6'd4:  axi_rdata <= ring_base_addr[63:32];
                    6'd5:  axi_rdata <= ctrl_base_addr[31:0];
                    6'd6:  axi_rdata <= ctrl_base_addr[63:32];
                    6'd7:  axi_rdata <= RING_LOG2;
                    6'd8:  axi_rdata <= SLOT_STRIDE;
                    6'd9:  axi_rdata <= produce_idx;
                    6'd10: axi_rdata <= consume_idx_shadow;
                    6'd11: axi_rdata <= drop_count;
                    6'd12: axi_rdata <= complete_count[31:0];
                    6'd13: axi_rdata <= complete_count[63:32];
                    6'd14: axi_rdata <= error_count;
                    6'd15: axi_rdata <= fault_code;
                    6'd16: axi_rdata <= irq_enable_reg;
                    6'd17: axi_rdata <= irq_status_reg;
                    default: axi_rdata <= 32'd0;
                endcase
                axi_rvalid  <= 1'b1;
            end
            if (axi_rvalid && S_AXI_RREADY)
                axi_rvalid <= 1'b0;
        end
    end

    // Ring writer FSM and AXI master channels.
    always @(posedge clk) begin
        if (rst) begin
            produce_idx        <= 32'd0;
            consume_idx_shadow <= 32'd0;
            consume_read_age   <= 6'd31;
            drop_count         <= 32'd0;
            error_count        <= 32'd0;
            complete_count     <= 64'd0;
            fault_code         <= 32'd0;
            writer_fault       <= 1'b0;
            writer_busy        <= 1'b0;
            writer_state       <= ST_IDLE;
            capture_word_count <= 8'd0;
            burst_word_index   <= 11'd0;
            burst_word_count   <= 5'd0;
            burst_beats_sent   <= 5'd0;
            target_slot        <= 11'd0;
            next_produce_slot  <= 11'd0;
            m_axi_awaddr       <= 32'd0;
            m_axi_awlen        <= 8'd0;
            m_axi_awvalid      <= 1'b0;
            m_axi_wdata        <= 64'd0;
            m_axi_wstrb        <= 8'hFF;
            m_axi_wlast        <= 1'b0;
            m_axi_wvalid       <= 1'b0;
            m_axi_bready       <= 1'b0;
            m_axi_araddr       <= 32'd0;
            m_axi_arvalid     <= 1'b0;
            m_axi_rready       <= 1'b0;
        end else begin
            if (!control_enable || writer_fault) begin
                writer_state <= writer_fault ? ST_ERROR : ST_IDLE;
                writer_busy  <= 1'b0;
                m_axi_awvalid <= 1'b0;
                m_axi_wvalid  <= 1'b0;
                m_axi_bready  <= 1'b0;
                m_axi_arvalid <= 1'b0;
                m_axi_rready  <= 1'b0;
            end else begin
                case (writer_state)
                    ST_IDLE: begin
                        writer_busy <= 1'b0;
                        if (base_invalid) begin
                            writer_fault <= 1'b1;
                            fault_code   <= FAULT_BASE;
                            error_count  <= error_count + 1'b1;
                            writer_state <= ST_ERROR;
                        end else begin
                            target_slot <= produce_idx[RING_LOG2-1:0];
                            if (consume_refresh) begin
                                m_axi_araddr <= ctrl_base_addr[31:0] + 32'd4;
                                m_axi_arvalid <= 1'b1;
                                m_axi_rready <= 1'b1;
                                writer_state <= ST_CTRL_AR;
                            end else begin
                                capture_word_count <= 8'd0;
                                writer_busy <= 1'b1;
                                writer_state <= ST_CAPTURE;
                            end
                        end
                    end

                    ST_CTRL_AR: begin
                        if (m_axi_arvalid && M_AXI_ARREADY)
                            m_axi_arvalid <= 1'b0;
                        if (M_AXI_RVALID && m_axi_rready) begin
                            m_axi_rready <= 1'b0;
                            consume_idx_shadow <= M_AXI_RDATA;
                            consume_read_age <= 6'd0;
                            if ((((produce_idx + 1) & ring_mask) ==
                                 (M_AXI_RDATA & ring_mask))) begin
                                drop_count <= drop_count + 1'b1;
                                writer_state <= ST_DROP;
                            end else begin
                                capture_word_count <= 8'd0;
                                writer_busy <= 1'b1;
                                writer_state <= ST_CAPTURE;
                            end
                            if (M_AXI_RRESP != 2'b00) begin
                                writer_fault <= 1'b1;
                                fault_code <= FAULT_CTRL_R;
                                error_count <= error_count + 1'b1;
                                writer_state <= ST_ERROR;
                            end
                        end
                    end

                    ST_CTRL_R: begin
                        // Reserved state. Reads complete in ST_CTRL_AR so the
                        // AXI read channel cannot be mistaken for packet data.
                        writer_state <= ST_IDLE;
                    end

                    ST_DROP: begin
                        // Drain exactly one complete packet. No DDR write is
                        // issued, so the drop is frame-atomic.
                        if (S_AXIS_TVALID && S_AXIS_TREADY && S_AXIS_TLAST)
                            writer_state <= ST_IDLE;
                    end

                    ST_CAPTURE: begin
                        if (S_AXIS_TVALID && S_AXIS_TREADY) begin
                            if ((capture_word_count == 0) &&
                                (S_AXIS_TKEEP == 16'h00FF)) begin
                                packet_buf[0] <= S_AXIS_TDATA[63:0];
                                capture_word_count <= 8'd1;
                            end else if (S_AXIS_TKEEP == 16'hFFFF &&
                                         capture_word_count != 0) begin
                                packet_buf[capture_word_count] <= S_AXIS_TDATA[63:0];
                                packet_buf[capture_word_count + 1'b1] <= S_AXIS_TDATA[127:64];
                                if (S_AXIS_TLAST) begin
                                    if (capture_word_count != PACKET_WORDS-2) begin
                                        writer_fault <= 1'b1;
                                        fault_code <= FAULT_LENGTH;
                                        error_count <= error_count + 1'b1;
                                        writer_state <= ST_ERROR;
                                    end else begin
                                        // Convert the 1240-byte B.1 body into
                                        // a complete 1280-byte slot. These
                                        // five words are deliberately zero;
                                        // they are sent as transport padding
                                        // by B.3 and are not GCM data.
                                        for (integer pad_word = PACKET_WORDS;
                                             pad_word < SLOT_WORDS;
                                             pad_word = pad_word + 1)
                                            packet_buf[pad_word] <= 64'd0;
                                        burst_word_index <= 11'd0;
                                        writer_state <= ST_PREP;
                                    end
                                end else begin
                                    capture_word_count <= capture_word_count + 2'd2;
                                end
                            end else begin
                                writer_fault <= 1'b1;
                                fault_code <= FAULT_TKEEP;
                                error_count <= error_count + 1'b1;
                                writer_state <= ST_ERROR;
                            end
                        end
                    end

                    ST_PREP: begin
                        writer_busy <= 1'b1;
                        if ((SLOT_WORDS - burst_word_index) > 16)
                            burst_word_count <= 5'd16;
                        else
                            burst_word_count <= SLOT_WORDS - burst_word_index;
                        m_axi_awaddr <= ring_slot_addr + (burst_word_index * 8);
                        m_axi_awlen <= (((SLOT_WORDS - burst_word_index) > 16) ? 8'd16 :
                                        (SLOT_WORDS - burst_word_index)) - 1'b1;
                        m_axi_awvalid <= 1'b1;
                        writer_state <= ST_AW;
                    end

                    ST_AW: begin
                        if (m_axi_awvalid && M_AXI_AWREADY) begin
                            m_axi_awvalid <= 1'b0;
                            burst_beats_sent <= 5'd0;
                            m_axi_wdata <= packet_buf[burst_word_index];
                            m_axi_wstrb <= 8'hFF;
                            m_axi_wlast <= (burst_word_count == 1);
                            m_axi_wvalid <= 1'b1;
                            writer_state <= ST_W;
                        end
                    end

                    ST_W: begin
                        if (m_axi_wvalid && M_AXI_WREADY) begin
                            if (burst_beats_sent + 1 >= burst_word_count) begin
                                m_axi_wvalid <= 1'b0;
                                m_axi_wlast  <= 1'b0;
                                m_axi_bready <= 1'b1;
                                writer_state <= ST_B;
                            end else begin
                                burst_beats_sent <= burst_beats_sent + 1'b1;
                                m_axi_wdata <= packet_buf[burst_word_index + burst_beats_sent + 1'b1];
                                m_axi_wlast <= (burst_beats_sent + 2 >= burst_word_count);
                            end
                        end
                    end

                    ST_B: begin
                        if (M_AXI_BVALID && m_axi_bready) begin
                            m_axi_bready <= 1'b0;
                            if (M_AXI_BRESP != 2'b00) begin
                                writer_fault <= 1'b1;
                                fault_code <= FAULT_BRESP;
                                error_count <= error_count + 1'b1;
                                writer_state <= ST_ERROR;
                            end else if (burst_word_index + burst_word_count >= SLOT_WORDS) begin
                                next_produce_slot <= (target_slot + 1'b1) & ring_mask;
                                m_axi_awaddr <= ctrl_base_addr[31:0];
                                m_axi_awlen <= 8'd0;
                                m_axi_awvalid <= 1'b1;
                                writer_state <= ST_PUB_AW;
                            end else begin
                                burst_word_index <= burst_word_index + burst_word_count;
                                writer_state <= ST_PREP;
                            end
                        end
                    end

                    ST_PUB_AW: begin
                        if (m_axi_awvalid && M_AXI_AWREADY) begin
                            m_axi_awvalid <= 1'b0;
                            m_axi_wdata <= {32'd0, next_produce_slot};
                            m_axi_wstrb <= 8'h0F;
                            m_axi_wlast <= 1'b1;
                            m_axi_wvalid <= 1'b1;
                            writer_state <= ST_PUB_W;
                        end
                    end

                    ST_PUB_W: begin
                        if (m_axi_wvalid && M_AXI_WREADY) begin
                            m_axi_wvalid <= 1'b0;
                            m_axi_wlast  <= 1'b0;
                            m_axi_bready <= 1'b1;
                            writer_state <= ST_PUB_B;
                        end
                    end

                    ST_PUB_B: begin
                        if (M_AXI_BVALID && m_axi_bready) begin
                            m_axi_bready <= 1'b0;
                            if (M_AXI_BRESP != 2'b00) begin
                                writer_fault <= 1'b1;
                                fault_code <= FAULT_CTRL_W;
                                error_count <= error_count + 1'b1;
                                writer_state <= ST_ERROR;
                            end else begin
                                produce_idx <= next_produce_slot;
                                consume_read_age <= consume_read_age + 1'b1;
                                complete_count <= complete_count + 1'b1;
                                writer_busy <= 1'b0;
                                writer_state <= ST_IDLE;
                            end
                        end
                    end

                    ST_ERROR: begin
                        writer_busy <= 1'b0;
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid <= 1'b0;
                        m_axi_bready <= 1'b0;
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready <= 1'b0;
                    end

                    default: writer_state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
