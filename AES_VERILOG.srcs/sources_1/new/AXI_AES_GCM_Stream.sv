`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite + AXI4-Stream wrapper for AES-256 GCM mode on PYNQ-Z2.
//
// Register map (32-bit words):
//   Addr   Name          R/W   Description
//   0x00   CTRL          W     [0] push_pt        (legacy AXI-Lite PT push)
//                                [1] load_key       (new_masterkey pulse)
//                                [2] start_session  (latch nonce/lengths if session_ready & h_valid)
//                                [3] push_aad       (accept one AAD block if aad_ready)
//                                [4] aad_last       (used with push_aad)
//                                [5] pt_last        (used with push_pt)
//                                [6] zeroize        (clear sensitive regs + reset datapath)
//                                [7] set_stream     (route PT/CT through AXI-Stream DMA path)
//                                [8] clear_stream   (route PT/CT through legacy AXI-Lite path)
//   0x04   STATUS        R     [3:0]  keys_ready
//                                [4]    session_ready
//                                [5]    aad_ready
//                                [6]    pt_ready
//                                [7]    busy
//                                [8]    h_valid
//                                [9]    ct_valid_sticky
//                                [10]   ct_last_sticky
//                                [11]   ghash_valid_sticky
//                                [12]   tag_valid_sticky
//                                [13]   aad_drop_sticky       (push_aad when not ready)
//                                [14]   pt_drop_sticky        (legacy push_pt when not ready, or bad TKEEP in stream mode)
//                                [15]   session_drop_sticky   (start_session when not ready)
//                                [16]   session_cycles_valid_sticky
//                                [17]   stream_mode           (1=AXI-Stream PT/CT path enabled)
//                                [18]   ct_fifo_overflow      (CT output FIFO overflow)
//   0x08   KEY0          R/W   masterkey[0:31]      (MSB)
//   0x0C   KEY1          R/W   masterkey[32:63]
//   0x10   KEY2          R/W   masterkey[64:95]
//   0x14   KEY3          R/W   masterkey[96:127]
//   0x18   KEY4          R/W   masterkey[128:159]
//   0x1C   KEY5          R/W   masterkey[160:191]
//   0x20   KEY6          R/W   masterkey[192:223]
//   0x24   KEY7          R/W   masterkey[224:255]   (LSB)
//   0x28   NONCE0        R/W   nonce[0:31]          (MSB)
//   0x2C   NONCE1        R/W   nonce[32:63]
//   0x30   NONCE2        R/W   nonce[64:95]         (LSB)
//   0x34   AAD_LEN_HI    R/W   aad_len_bits[0:31]   (MSB)
//   0x38   AAD_LEN_LO    R/W   aad_len_bits[32:63]  (LSB)
//   0x3C   PT_LEN_HI     R/W   pt_len_bits[0:31]    (MSB)
//   0x40   PT_LEN_LO     R/W   pt_len_bits[32:63]   (LSB)
//   0x44   AAD0          R/W   aad_data[0:31]
//   0x48   AAD1          R/W   aad_data[32:63]
//   0x4C   AAD2          R/W   aad_data[64:95]
//   0x50   AAD3          R/W   aad_data[96:127]
//   0x54   PT0           R/W   pt_data[0:31]        (legacy AXI-Lite PT path)
//   0x58   PT1           R/W   pt_data[32:63]
//   0x5C   PT2           R/W   pt_data[64:95]
//   0x60   PT3           R/W   pt_data[96:127]
//   0x64   CTR_VAL       R     counter_val
//   0x68   CT0           R     latched ct_data[0:31]
//   0x6C   CT1           R     latched ct_data[32:63]
//   0x70   CT2           R     latched ct_data[64:95]
//   0x74   CT3           R     latched ct_data[96:127]
//   0x78   GHASH0        R     latched ghash[0:31]
//   0x7C   GHASH1        R     latched ghash[32:63]
//   0x80   GHASH2        R     latched ghash[64:95]
//   0x84   GHASH3        R     latched ghash[96:127]
//   0x88   TAG0          R     latched tag[0:31]
//   0x8C   TAG1          R     latched tag[32:63]
//   0x90   TAG2          R     latched tag[64:95]
//   0x94   TAG3          R     latched tag[96:127]
//   0x98   CYCLES        R     latched session cycle count (start_session -> tag_valid)
//   0x9C   STREAM_CYCLES R     latched stream cycle count (first PT beat -> tag_valid)
//////////////////////////////////////////////////////////////////////////////////

module AXI_AES_GCM_Stream #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8,
    parameter integer STREAM_FIFO_DEPTH = 64
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

    // AXI4-Stream plaintext input (DMA MM2S -> core)
    input  wire [127:0]                        S_AXIS_PT_TDATA,
    input  wire [15:0]                         S_AXIS_PT_TKEEP,
    input  wire                                S_AXIS_PT_TLAST,
    input  wire                                S_AXIS_PT_TVALID,
    output wire                                S_AXIS_PT_TREADY,

    // AXI4-Stream ciphertext output (core -> DMA S2MM)
    output wire [127:0]                        M_AXIS_CT_TDATA,
    output wire [15:0]                         M_AXIS_CT_TKEEP,
    output wire                                M_AXIS_CT_TLAST,
    output wire                                M_AXIS_CT_TVALID,
    input  wire                                M_AXIS_CT_TREADY
);

    localparam integer STREAM_FIFO_PTR_W = $clog2(STREAM_FIFO_DEPTH);

    function automatic [STREAM_FIFO_PTR_W-1:0] ptr_inc;
        input [STREAM_FIFO_PTR_W-1:0] ptr;
        begin
            if (ptr == STREAM_FIFO_DEPTH - 1)
                ptr_inc = {STREAM_FIFO_PTR_W{1'b0}};
            else
                ptr_inc = ptr + 1'b1;
        end
    endfunction

    // ----------------------------------------------------------------
    // Internal signals
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // User registers / command pulses
    // ----------------------------------------------------------------
    reg [0:255] key_reg;
    reg [0:95]  nonce_reg;
    reg [0:63]  aad_len_bits_reg;
    reg [0:63]  pt_len_bits_reg;
    reg [0:127] aad_data_reg;
    reg [0:127] pt_data_reg;

    reg         stream_mode_reg;

    reg         load_key_pulse;
    reg         start_session_pulse;
    reg         aad_valid_pulse;
    reg         aad_last_pulse;
    reg         pt_valid_pulse;
    reg         pt_last_pulse;
    reg         zeroize_pulse;

    // ----------------------------------------------------------------
    // GcmMode interface wires
    // ----------------------------------------------------------------
    wire [3:0]   keys_ready;
    wire         session_ready;
    wire         aad_ready;
    wire         pt_ready;

    wire [0:127] ct_data;
    wire         ct_valid;
    wire         ct_last;

    wire [0:127] ghash_out;
    wire         ghash_valid;
    wire [0:127] tag_out;
    wire         tag_valid;

    wire [0:31]  counter_val;
    wire         h_valid;
    wire         busy;
    wire [0:31]  session_cycles;
    wire         session_cycles_valid;

    wire [5:0] wr_index = axi_awaddr[7:2];
    wire [5:0] rd_index = axi_araddr[7:2];

    wire wr_handshake = axi_awready && S_AXI_AWVALID
                     && axi_wready  && S_AXI_WVALID;

    wire ctrl_write            = wr_handshake && (wr_index == 6'd0);
    wire cmd_push_pt           = ctrl_write && S_AXI_WDATA[0];
    wire cmd_load_key          = ctrl_write && S_AXI_WDATA[1];
    wire cmd_start_session     = ctrl_write && S_AXI_WDATA[2];
    wire cmd_push_aad          = ctrl_write && S_AXI_WDATA[3];
    wire cmd_aad_last          = ctrl_write && S_AXI_WDATA[4];
    wire cmd_pt_last           = ctrl_write && S_AXI_WDATA[5];
    wire cmd_zeroize           = ctrl_write && S_AXI_WDATA[6];
    wire cmd_set_stream_mode   = ctrl_write && S_AXI_WDATA[7];
    wire cmd_clear_stream_mode = ctrl_write && S_AXI_WDATA[8];

    // Datapath reset combines AXI reset + zeroize command.
    wire rst = rst_axi | zeroize_pulse | cmd_zeroize;

    // ----------------------------------------------------------------
    // AXI-Stream PT input conversion and handshake
    // ----------------------------------------------------------------
    wire pt_keep_ok = (S_AXIS_PT_TKEEP == 16'hFFFF);

    // CT FIFO and in-flight accounting prevent output overflow under backpressure.
    reg [0:127] ct_fifo_data [0:STREAM_FIFO_DEPTH-1];
    reg         ct_fifo_last [0:STREAM_FIFO_DEPTH-1];

    reg [STREAM_FIFO_PTR_W-1:0] ct_fifo_wr_ptr;
    reg [STREAM_FIFO_PTR_W-1:0] ct_fifo_rd_ptr;
    reg [STREAM_FIFO_PTR_W:0]   ct_fifo_count;
    reg [STREAM_FIFO_PTR_W:0]   pt_inflight_count;
    reg                         ct_fifo_overflow_sticky;

    wire ct_fifo_empty = (ct_fifo_count == 0);
    wire ct_fifo_full  = (ct_fifo_count == STREAM_FIFO_DEPTH);

    wire [STREAM_FIFO_PTR_W:0] total_outstanding = ct_fifo_count + pt_inflight_count;
    wire stream_can_accept_pt = (total_outstanding < STREAM_FIFO_DEPTH);

    assign S_AXIS_PT_TREADY = stream_mode_reg && pt_ready && stream_can_accept_pt && pt_keep_ok;
    wire pt_stream_accept = stream_mode_reg && S_AXIS_PT_TVALID && S_AXIS_PT_TREADY;

    wire [0:127] pt_stream_data;
    wire [0:127] ct_stream_head = ct_fifo_data[ct_fifo_rd_ptr];

    genvar b;
    generate
        for (b = 0; b < 16; b = b + 1) begin : g_axis_byte_map
            // Keep a native 1:1 lane mapping between DMA stream and core byte lanes.
            assign pt_stream_data[b*8 +: 8] = S_AXIS_PT_TDATA[b*8 +: 8];
            assign M_AXIS_CT_TDATA[b*8 +: 8] = ct_stream_head[b*8 +: 8];
        end
    endgenerate

    assign M_AXIS_CT_TKEEP  = 16'hFFFF;
    assign M_AXIS_CT_TVALID = stream_mode_reg && !ct_fifo_empty;
    assign M_AXIS_CT_TLAST  = (!ct_fifo_empty) ? ct_fifo_last[ct_fifo_rd_ptr] : 1'b0;

    wire [0:127] pt_data_mux  = stream_mode_reg ? pt_stream_data : pt_data_reg;
    wire         pt_valid_mux = stream_mode_reg ? pt_stream_accept : pt_valid_pulse;
    wire         pt_last_mux  = stream_mode_reg ? S_AXIS_PT_TLAST : pt_last_pulse;

    GcmMode gm(
        .clk(clk),
        .rst(rst),
        .new_masterkey(load_key_pulse),
        .masterkey(key_reg),
        .keys_ready(keys_ready),
        .session_start_i(start_session_pulse),
        .nonce_i(nonce_reg),
        .aad_len_bits_i(aad_len_bits_reg),
        .pt_len_bits_i(pt_len_bits_reg),
        .session_ready_o(session_ready),
        .aad_data_i(aad_data_reg),
        .aad_valid_i(aad_valid_pulse),
        .aad_last_i(aad_last_pulse),
        .aad_ready_o(aad_ready),
        .pt_data_i(pt_data_mux),
        .pt_valid_i(pt_valid_mux),
        .pt_last_i(pt_last_mux),
        .pt_ready_o(pt_ready),
        .ct_data_o(ct_data),
        .ct_valid_o(ct_valid),
        .ct_last_o(ct_last),
        .ghash_out_o(ghash_out),
        .ghash_valid_o(ghash_valid),
        .tag_out_o(tag_out),
        .tag_valid_o(tag_valid),
        .counter_val_o(counter_val),
        .h_valid_o(h_valid),
        .busy_o(busy),
        .session_cycles_o(session_cycles),
        .session_cycles_valid_o(session_cycles_valid)
    );

    // ----------------------------------------------------------------
    // Sticky outputs / status latches for AXI polling
    // ----------------------------------------------------------------
    reg         ct_valid_sticky;
    reg         ct_last_sticky;
    reg         ghash_valid_sticky;
    reg         tag_valid_sticky;
    reg         aad_drop_sticky;
    reg         pt_drop_sticky;
    reg         session_drop_sticky;
    reg         session_cycles_valid_sticky;

    reg [0:127] ct_data_latched;
    reg [0:127] ghash_latched;
    reg [0:127] tag_latched;
    reg [0:31]  session_cycles_latched;
    reg         stream_cycles_active;
    reg [0:31]  stream_cycles_live;
    reg [0:31]  stream_cycles_latched;

    always_ff @(posedge clk) begin
        if (rst) begin
            ct_valid_sticky     <= 1'b0;
            ct_last_sticky      <= 1'b0;
            ghash_valid_sticky  <= 1'b0;
            tag_valid_sticky    <= 1'b0;
            aad_drop_sticky     <= 1'b0;
            pt_drop_sticky      <= 1'b0;
            session_drop_sticky <= 1'b0;
            session_cycles_valid_sticky <= 1'b0;
            ct_data_latched     <= '0;
            ghash_latched       <= '0;
            tag_latched         <= '0;
            session_cycles_latched <= '0;
            stream_cycles_active   <= 1'b0;
            stream_cycles_live     <= '0;
            stream_cycles_latched  <= '0;
        end
        else begin
            if (start_session_pulse) begin
                ct_valid_sticky     <= 1'b0;
                ghash_valid_sticky  <= 1'b0;
                tag_valid_sticky    <= 1'b0;
                ct_last_sticky      <= 1'b0;
                aad_drop_sticky     <= 1'b0;
                pt_drop_sticky      <= 1'b0;
                session_drop_sticky <= 1'b0;
                session_cycles_valid_sticky <= 1'b0;
                stream_cycles_active   <= 1'b0;
                stream_cycles_live     <= '0;
                stream_cycles_latched  <= '0;
            end

            if (pt_valid_mux) begin
                ct_valid_sticky <= 1'b0;
                ct_last_sticky  <= 1'b0;
            end

            if (ct_valid) begin
                ct_valid_sticky <= 1'b1;
                ct_last_sticky  <= ct_last;
                ct_data_latched <= ct_data;
            end

            if (ghash_valid) begin
                ghash_valid_sticky <= 1'b1;
                ghash_latched      <= ghash_out;
            end

            if (tag_valid) begin
                tag_valid_sticky <= 1'b1;
                tag_latched      <= tag_out;
            end

            if (session_cycles_valid) begin
                session_cycles_valid_sticky <= 1'b1;
                session_cycles_latched      <= session_cycles;
            end

            if (!start_session_pulse) begin
                // Count datapath cycles only from first accepted stream PT beat to tag_valid.
                if (!stream_cycles_active) begin
                    if (stream_mode_reg && pt_stream_accept) begin
                        stream_cycles_active <= 1'b1;
                        stream_cycles_live   <= 32'd1;
                    end
                end
                else if (tag_valid) begin
                    stream_cycles_latched <= stream_cycles_live + 32'd1;
                    stream_cycles_active  <= 1'b0;
                end
                else begin
                    stream_cycles_live <= stream_cycles_live + 32'd1;
                end
            end

            if (cmd_push_aad && !aad_ready)
                aad_drop_sticky <= 1'b1;

            if ((!stream_mode_reg && cmd_push_pt && !pt_ready) ||
                (stream_mode_reg && S_AXIS_PT_TVALID && !pt_keep_ok))
                pt_drop_sticky <= 1'b1;

            if (cmd_start_session && !(session_ready && h_valid))
                session_drop_sticky <= 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // Stream-side CT FIFO and in-flight accounting
    // ----------------------------------------------------------------
    wire ct_fifo_push = stream_mode_reg && ct_valid;
    wire ct_fifo_pop  = stream_mode_reg && !ct_fifo_empty && M_AXIS_CT_TREADY;

    always_ff @(posedge clk) begin
        if (rst) begin
            ct_fifo_wr_ptr <= '0;
            ct_fifo_rd_ptr <= '0;
            ct_fifo_count  <= '0;
            pt_inflight_count <= '0;
            ct_fifo_overflow_sticky <= 1'b0;
        end
        else if (start_session_pulse) begin
            // Start every session with empty stream buffers.
            ct_fifo_wr_ptr <= '0;
            ct_fifo_rd_ptr <= '0;
            ct_fifo_count  <= '0;
            pt_inflight_count <= '0;
            ct_fifo_overflow_sticky <= 1'b0;
        end
        else begin
            if (ct_fifo_push) begin
                if (!ct_fifo_full) begin
                    ct_fifo_data[ct_fifo_wr_ptr] <= ct_data;
                    ct_fifo_last[ct_fifo_wr_ptr] <= ct_last;
                    ct_fifo_wr_ptr <= ptr_inc(ct_fifo_wr_ptr);
                end
                else begin
                    ct_fifo_overflow_sticky <= 1'b1;
                end
            end

            if (ct_fifo_pop)
                ct_fifo_rd_ptr <= ptr_inc(ct_fifo_rd_ptr);

            case ({ct_fifo_push && !ct_fifo_full, ct_fifo_pop})
                2'b10: ct_fifo_count <= ct_fifo_count + 1'b1;
                2'b01: ct_fifo_count <= ct_fifo_count - 1'b1;
                default: ;
            endcase

            case ({pt_stream_accept, ct_fifo_push})
                2'b10: pt_inflight_count <= pt_inflight_count + 1'b1;
                2'b01: if (pt_inflight_count != 0)
                           pt_inflight_count <= pt_inflight_count - 1'b1;
                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // AXI Write Address + Write Data (accept together)
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // Write Response
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end
        else if (wr_handshake && ~axi_bvalid) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;
        end
        else if (S_AXI_BREADY && axi_bvalid)
            axi_bvalid <= 1'b0;
    end

    // ----------------------------------------------------------------
    // Register Writes
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_axi || cmd_zeroize) begin
            key_reg             <= '0;
            nonce_reg           <= '0;
            aad_len_bits_reg    <= '0;
            pt_len_bits_reg     <= '0;
            aad_data_reg        <= '0;
            pt_data_reg         <= '0;

            stream_mode_reg     <= 1'b0;

            load_key_pulse      <= 1'b0;
            start_session_pulse <= 1'b0;
            aad_valid_pulse     <= 1'b0;
            aad_last_pulse      <= 1'b0;
            pt_valid_pulse      <= 1'b0;
            pt_last_pulse       <= 1'b0;
            zeroize_pulse       <= 1'b0;
        end
        else begin
            // Auto-clear pulses every cycle
            load_key_pulse      <= 1'b0;
            start_session_pulse <= 1'b0;
            aad_valid_pulse     <= 1'b0;
            aad_last_pulse      <= 1'b0;
            pt_valid_pulse      <= 1'b0;
            pt_last_pulse       <= 1'b0;
            zeroize_pulse       <= 1'b0;

            if (wr_handshake) begin
                case (wr_index)
                    6'd0: begin
                        load_key_pulse <= cmd_load_key;
                        zeroize_pulse  <= cmd_zeroize;

                        if (cmd_set_stream_mode)
                            stream_mode_reg <= 1'b1;

                        if (cmd_clear_stream_mode)
                            stream_mode_reg <= 1'b0;

                        if (cmd_start_session && session_ready && h_valid)
                            start_session_pulse <= 1'b1;

                        if (cmd_push_aad && aad_ready) begin
                            aad_valid_pulse <= 1'b1;
                            aad_last_pulse  <= cmd_aad_last;
                        end

                        if (!stream_mode_reg && cmd_push_pt && pt_ready) begin
                            pt_valid_pulse <= 1'b1;
                            pt_last_pulse  <= cmd_pt_last;
                        end
                    end

                    6'd2:  key_reg[0   +:32] <= S_AXI_WDATA;   // KEY0
                    6'd3:  key_reg[32  +:32] <= S_AXI_WDATA;   // KEY1
                    6'd4:  key_reg[64  +:32] <= S_AXI_WDATA;   // KEY2
                    6'd5:  key_reg[96  +:32] <= S_AXI_WDATA;   // KEY3
                    6'd6:  key_reg[128 +:32] <= S_AXI_WDATA;   // KEY4
                    6'd7:  key_reg[160 +:32] <= S_AXI_WDATA;   // KEY5
                    6'd8:  key_reg[192 +:32] <= S_AXI_WDATA;   // KEY6
                    6'd9:  key_reg[224 +:32] <= S_AXI_WDATA;   // KEY7

                    6'd10: nonce_reg[0  +:32] <= S_AXI_WDATA;  // NONCE0
                    6'd11: nonce_reg[32 +:32] <= S_AXI_WDATA;  // NONCE1
                    6'd12: nonce_reg[64 +:32] <= S_AXI_WDATA;  // NONCE2

                    6'd13: aad_len_bits_reg[0  +:32] <= S_AXI_WDATA; // AAD_LEN_HI
                    6'd14: aad_len_bits_reg[32 +:32] <= S_AXI_WDATA; // AAD_LEN_LO
                    6'd15: pt_len_bits_reg[0   +:32] <= S_AXI_WDATA; // PT_LEN_HI
                    6'd16: pt_len_bits_reg[32  +:32] <= S_AXI_WDATA; // PT_LEN_LO

                    6'd17: aad_data_reg[0   +:32] <= S_AXI_WDATA; // AAD0
                    6'd18: aad_data_reg[32  +:32] <= S_AXI_WDATA; // AAD1
                    6'd19: aad_data_reg[64  +:32] <= S_AXI_WDATA; // AAD2
                    6'd20: aad_data_reg[96  +:32] <= S_AXI_WDATA; // AAD3

                    6'd21: pt_data_reg[0   +:32] <= S_AXI_WDATA; // PT0
                    6'd22: pt_data_reg[32  +:32] <= S_AXI_WDATA; // PT1
                    6'd23: pt_data_reg[64  +:32] <= S_AXI_WDATA; // PT2
                    6'd24: pt_data_reg[96  +:32] <= S_AXI_WDATA; // PT3

                    default: ;
                endcase
            end
        end
    end

    // ----------------------------------------------------------------
    // AXI Read Address
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_axi) begin
            axi_arready <= 1'b0;
            axi_araddr  <= '0;
        end
        else if (~axi_arready && S_AXI_ARVALID) begin
            axi_arready <= 1'b1;
            axi_araddr  <= S_AXI_ARADDR;
        end
        else
            axi_arready <= 1'b0;
    end

    // ----------------------------------------------------------------
    // Read Data + Response
    // ----------------------------------------------------------------
    reg [C_S_AXI_DATA_WIDTH-1:0] rd_mux;

    always_comb begin
        case (rd_index)
            6'd1:  rd_mux = {12'b0,
                             ct_fifo_overflow_sticky,
                             stream_mode_reg,
                             session_cycles_valid_sticky,
                             session_drop_sticky,
                             pt_drop_sticky,
                             aad_drop_sticky,
                             tag_valid_sticky,
                             ghash_valid_sticky,
                             ct_last_sticky,
                             ct_valid_sticky,
                             h_valid,
                             busy,
                             pt_ready,
                             aad_ready,
                             session_ready,
                             keys_ready};

            6'd2:  rd_mux = key_reg[0   +:32];
            6'd3:  rd_mux = key_reg[32  +:32];
            6'd4:  rd_mux = key_reg[64  +:32];
            6'd5:  rd_mux = key_reg[96  +:32];
            6'd6:  rd_mux = key_reg[128 +:32];
            6'd7:  rd_mux = key_reg[160 +:32];
            6'd8:  rd_mux = key_reg[192 +:32];
            6'd9:  rd_mux = key_reg[224 +:32];

            6'd10: rd_mux = nonce_reg[0  +:32];
            6'd11: rd_mux = nonce_reg[32 +:32];
            6'd12: rd_mux = nonce_reg[64 +:32];

            6'd13: rd_mux = aad_len_bits_reg[0  +:32];
            6'd14: rd_mux = aad_len_bits_reg[32 +:32];
            6'd15: rd_mux = pt_len_bits_reg[0   +:32];
            6'd16: rd_mux = pt_len_bits_reg[32  +:32];

            6'd17: rd_mux = aad_data_reg[0   +:32];
            6'd18: rd_mux = aad_data_reg[32  +:32];
            6'd19: rd_mux = aad_data_reg[64  +:32];
            6'd20: rd_mux = aad_data_reg[96  +:32];

            6'd21: rd_mux = pt_data_reg[0   +:32];
            6'd22: rd_mux = pt_data_reg[32  +:32];
            6'd23: rd_mux = pt_data_reg[64  +:32];
            6'd24: rd_mux = pt_data_reg[96  +:32];

            6'd25: rd_mux = counter_val;

            6'd26: rd_mux = ct_data_latched[0   +:32];
            6'd27: rd_mux = ct_data_latched[32  +:32];
            6'd28: rd_mux = ct_data_latched[64  +:32];
            6'd29: rd_mux = ct_data_latched[96  +:32];

            6'd30: rd_mux = ghash_latched[0   +:32];
            6'd31: rd_mux = ghash_latched[32  +:32];
            6'd32: rd_mux = ghash_latched[64  +:32];
            6'd33: rd_mux = ghash_latched[96  +:32];

            6'd34: rd_mux = tag_latched[0   +:32];
            6'd35: rd_mux = tag_latched[32  +:32];
            6'd36: rd_mux = tag_latched[64  +:32];
            6'd37: rd_mux = tag_latched[96  +:32];
            6'd38: rd_mux = session_cycles_latched;
            6'd39: rd_mux = stream_cycles_latched;

            default: rd_mux = 32'd0;
        endcase
    end

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
        else if (axi_rvalid && S_AXI_RREADY)
            axi_rvalid <= 1'b0;
    end

endmodule
