`timescale 1ns / 1ps

module AES_GCM_Session_Sequencer #(
    parameter int unsigned C_AXI_ADDR_WIDTH = 8,
    parameter int unsigned C_AXI_DATA_WIDTH = 32,
    parameter logic [31:0] DEFAULT_SESSION_ID = 32'h0000_0001,
    parameter logic [15:0] DEFAULT_STREAM_ID = 16'h0001,
    parameter logic [7:0]  DEFAULT_PAYLOAD_TYPE = 8'd1,
    parameter logic [7:0]  DEFAULT_KEY_ID = 8'd1,
    parameter logic [31:0] DEFAULT_NONCE_DOMAIN = 32'h0000_0001,
    parameter logic [63:0] DEFAULT_NONCE_SEED = 64'd1,
    parameter logic [15:0] DEFAULT_PAYLOAD_BYTES = 16'd1200,
    parameter logic [15:0] HEADER_BYTES = 16'd40
) (
    input  logic         aclk,
    input  logic         aresetn,

    input  logic [127:0] s_axis_tdata,
    input  logic [15:0]  s_axis_tkeep,
    input  logic         s_axis_tvalid,
    output logic         s_axis_tready,
    input  logic         s_axis_tlast,

    output logic [127:0] m_axis_tdata,
    output logic [15:0]  m_axis_tkeep,
    output logic         m_axis_tvalid,
    input  logic         m_axis_tready,
    output logic         m_axis_tlast,

    // AXI-Lite slave for PS configuration.
    input  logic [C_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic [2:0]                  S_AXI_AWPROT,
    input  logic                        S_AXI_AWVALID,
    output logic                        S_AXI_AWREADY,
    input  logic [C_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  logic [3:0]                  S_AXI_WSTRB,
    input  logic                        S_AXI_WVALID,
    output logic                        S_AXI_WREADY,
    output logic [1:0]                  S_AXI_BRESP,
    output logic                        S_AXI_BVALID,
    input  logic                        S_AXI_BREADY,
    input  logic [C_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic [2:0]                  S_AXI_ARPROT,
    input  logic                        S_AXI_ARVALID,
    output logic                        S_AXI_ARREADY,
    output logic [C_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output logic [1:0]                  S_AXI_RRESP,
    output logic                        S_AXI_RVALID,
    input  logic                        S_AXI_RREADY,

    // AXI-Lite master to aes_gcm_0/S_AXI.
    output logic [C_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output logic [2:0]                  M_AXI_AWPROT,
    output logic                        M_AXI_AWVALID,
    input  logic                        M_AXI_AWREADY,
    output logic [C_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output logic [3:0]                  M_AXI_WSTRB,
    output logic                        M_AXI_WVALID,
    input  logic                        M_AXI_WREADY,
    input  logic [1:0]                  M_AXI_BRESP,
    input  logic                        M_AXI_BVALID,
    output logic                        M_AXI_BREADY,
    output logic [C_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output logic [2:0]                  M_AXI_ARPROT,
    output logic                        M_AXI_ARVALID,
    input  logic                        M_AXI_ARREADY,
    input  logic [C_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  logic [1:0]                  M_AXI_RRESP,
    input  logic                        M_AXI_RVALID,
    output logic                        M_AXI_RREADY,

    // Runtime config outputs to packetizer.
    output logic [31:0] cfg_session_id,
    output logic [15:0] cfg_stream_id,
    output logic [7:0]  cfg_payload_type,
    output logic [7:0]  cfg_key_id,
    output logic [15:0] cfg_payload_bytes,
    output logic [63:0] cfg_nonce_counter,
    output logic        cfg_enable,

    output logic [63:0] nonce_counter_out,
    output logic        seq_busy,

    // Free-running diagnostic counters from hdmi_packetizer_0, exposed as
    // read-only AXI-Lite registers so software can see if video beats/frames
    // ever reach the packetizer.
    input  logic [63:0] dbg_video_beat_count,
    input  logic [63:0] dbg_video_frame_count,

    // Debug probes from the AES wrapper (captured per tag beat).
    input  logic [127:0] dbg_push_data,
    input  logic [127:0] dbg_maxis_last_beat,
    input  logic [31:0]  dbg_ct_beats,
    input  logic [31:0]  dbg_tag_pushes,
    input  logic [31:0]  dbg_tag_fifo_count,
    input  logic [31:0]  dbg_tag_pt_inflight,
    input  logic [31:0]  dbg_last_ct_beats,
    input  logic [31:0]  dbg_last_fifo_pushes,
    input  logic [31:0]  dbg_last_axis_pops,
    input  logic [31:0]  dbg_last_tag_attempts,
    input  logic [31:0]  dbg_last_fifo_count,
    // Pre-FIFO probe counter (video_out tvalid) from video_beat_counter_0.
    input  logic [63:0] dbg_prefifo_beats
);

    // AES register addresses.
    localparam logic [7:0] AES_REG_CTRL        = 8'h00;
    localparam logic [7:0] AES_REG_STATUS      = 8'h04;
    localparam logic [7:0] AES_REG_KEY0        = 8'h08;
    localparam logic [7:0] AES_REG_NONCE0      = 8'h28;
    localparam logic [7:0] AES_REG_NONCE1      = 8'h2C;
    localparam logic [7:0] AES_REG_NONCE2      = 8'h30;
    localparam logic [7:0] AES_REG_AAD_LEN_HI  = 8'h34;
    localparam logic [7:0] AES_REG_AAD_LEN_LO  = 8'h38;
    localparam logic [7:0] AES_REG_PT_LEN_HI   = 8'h3C;
    localparam logic [7:0] AES_REG_PT_LEN_LO   = 8'h40;
    localparam logic [7:0] AES_REG_TAG0        = 8'h88;
    localparam logic [7:0] AES_REG_TAG1        = 8'h8C;
    localparam logic [7:0] AES_REG_TAG2        = 8'h90;
    localparam logic [7:0] AES_REG_TAG3        = 8'h94;
    localparam logic [7:0] AES_REG_GHASH0      = 8'h78;
    localparam logic [7:0] AES_REG_GHASH1      = 8'h7C;
    localparam logic [7:0] AES_REG_GHASH2      = 8'h80;
    localparam logic [7:0] AES_REG_GHASH3      = 8'h84;

    // Sequencer AXI-Lite register map.
    localparam logic [7:0] REG_CTRL          = 8'h00;
    localparam logic [7:0] REG_STATUS        = 8'h04;
    localparam logic [7:0] REG_SESSION_ID    = 8'h08;
    localparam logic [7:0] REG_STREAM_PAYLOAD= 8'h0C;
    localparam logic [7:0] REG_NONCE_DOMAIN  = 8'h10;
    localparam logic [7:0] REG_NONCE_SEED_HI = 8'h14;
    localparam logic [7:0] REG_NONCE_SEED_LO = 8'h18;
    localparam logic [7:0] REG_PAYLOAD_BYTES = 8'h1C;
    localparam logic [7:0] REG_KEY0          = 8'h20;
    localparam logic [7:0] REG_KEY1          = 8'h24;
    localparam logic [7:0] REG_KEY2          = 8'h28;
    localparam logic [7:0] REG_KEY3          = 8'h2C;
    localparam logic [7:0] REG_KEY4          = 8'h30;
    localparam logic [7:0] REG_KEY5          = 8'h34;
    localparam logic [7:0] REG_KEY6          = 8'h38;
    localparam logic [7:0] REG_KEY7          = 8'h3C;
    localparam logic [7:0] REG_NONCE_CUR_HI  = 8'h40;
    localparam logic [7:0] REG_NONCE_CUR_LO  = 8'h44;
    localparam logic [7:0] REG_VIDEO_BEAT_COUNT_HI  = 8'h48;
    localparam logic [7:0] REG_VIDEO_BEAT_COUNT_LO  = 8'h4C;
    localparam logic [7:0] REG_VIDEO_FRAME_COUNT_HI = 8'h50;
    localparam logic [7:0] REG_VIDEO_FRAME_COUNT_LO = 8'h54;
    localparam logic [7:0] REG_PREFIFO_BEAT_HI = 8'h58;
    localparam logic [7:0] REG_PREFIFO_BEAT_LO = 8'h5C;
    localparam logic [7:0] REG_TAG0 = 8'h60;
    localparam logic [7:0] REG_TAG1 = 8'h64;
    localparam logic [7:0] REG_TAG2 = 8'h68;
    localparam logic [7:0] REG_TAG3 = 8'h6C;
    localparam logic [7:0] REG_TAG_VALID = 8'h70;
    localparam logic [7:0] REG_GHASH0 = 8'h74;
    localparam logic [7:0] REG_GHASH1 = 8'h78;
    localparam logic [7:0] REG_GHASH2 = 8'h7C;
    localparam logic [7:0] REG_GHASH3 = 8'h80;
    localparam logic [7:0] REG_DBG_PUSH0 = 8'h84;
    localparam logic [7:0] REG_DBG_PUSH1 = 8'h88;
    localparam logic [7:0] REG_DBG_PUSH2 = 8'h8C;
    localparam logic [7:0] REG_DBG_PUSH3 = 8'h90;
    localparam logic [7:0] REG_DBG_MAXIS0 = 8'h94;
    localparam logic [7:0] REG_DBG_MAXIS1 = 8'h98;
    localparam logic [7:0] REG_DBG_MAXIS2 = 8'h9C;
    localparam logic [7:0] REG_DBG_MAXIS3 = 8'hA0;
    localparam logic [7:0] REG_AES_STATUS = 8'hA4;
    localparam logic [7:0] REG_DBG_CT_BEATS = 8'hA8;
    localparam logic [7:0] REG_DBG_TAG_PUSHES = 8'hAC;
    localparam logic [7:0] REG_DBG_TAG_FIFO_COUNT = 8'hB0;
    localparam logic [7:0] REG_DBG_TAG_PT_INFLIGHT = 8'hB4;
    localparam logic [7:0] REG_DBG_LAST_CT_BEATS = 8'hB8;
    localparam logic [7:0] REG_DBG_LAST_FIFO_PUSHES = 8'hBC;
    localparam logic [7:0] REG_DBG_LAST_AXIS_POPS = 8'hC0;
    localparam logic [7:0] REG_DBG_LAST_TAG_ATTEMPTS = 8'hC4;
    localparam logic [7:0] REG_DBG_LAST_FIFO_COUNT = 8'hC8;

    // Sequencer control bits.
    localparam logic [31:0] CTRL_ENABLE          = 32'h0000_0001;
    localparam logic [31:0] CTRL_LOAD_KEY_REQ    = 32'h0000_0002;
    localparam logic [31:0] CTRL_APPLY_NONCE_SEED= 32'h0000_0004;
    localparam logic [31:0] CTRL_FORCE_KEY_DIRTY = 32'h0000_0008;

    // AES CTRL bits.
    localparam logic [31:0] AES_CTRL_LOAD_KEY     = 32'h0000_0002;
    localparam logic [31:0] AES_CTRL_START_SESSION= 32'h0000_0004;
    localparam logic [31:0] AES_CTRL_SET_STREAM   = 32'h0000_0080;

    // AES STATUS bits.
    localparam logic [31:0] AES_STATUS_KEYS_READY = 32'h0000_000F;
    localparam logic [31:0] AES_STATUS_SESSION_RDY= 32'h0000_0010;
    localparam logic [31:0] AES_STATUS_H_VALID    = 32'h0000_0100;

    typedef enum logic [4:0] {
        ST_IDLE            = 5'd0,
        ST_W_KEY0          = 5'd1,
        ST_W_KEY1          = 5'd2,
        ST_W_KEY2          = 5'd3,
        ST_W_KEY3          = 5'd4,
        ST_W_KEY4          = 5'd5,
        ST_W_KEY5          = 5'd6,
        ST_W_KEY6          = 5'd7,
        ST_W_KEY7          = 5'd8,
        ST_W_LOAD_KEY      = 5'd9,
        ST_POLL_KEYS       = 5'd10,
        ST_W_NONCE0        = 5'd11,
        ST_W_NONCE1        = 5'd12,
        ST_W_NONCE2        = 5'd13,
        ST_W_AAD_HI        = 5'd14,
        ST_W_AAD_LO        = 5'd15,
        ST_W_PT_HI         = 5'd16,
        ST_W_PT_LO         = 5'd17,
        ST_W_SET_STREAM    = 5'd18,
        ST_W_START_SESS    = 5'd19,
        ST_POLL_SESSION    = 5'd20,
        ST_PASS            = 5'd21,
        ST_WAIT_TAG        = 5'd22,
        ST_RD_TAG0         = 5'd23,
        ST_RD_TAG1         = 5'd24,
        ST_RD_TAG2         = 5'd25,
        ST_RD_TAG3         = 5'd26,
        ST_RD_GHASH0       = 5'd27,
        ST_RD_GHASH1       = 5'd28,
        ST_RD_GHASH2       = 5'd29,
        ST_RD_GHASH3       = 5'd30
    } state_t;

    state_t state;
    logic [63:0] nonce_ctr;

    logic [31:0] reg_ctrl;
    logic [31:0] reg_session_id;
    logic [15:0] reg_stream_id;
    logic [7:0]  reg_payload_type;
    logic [7:0]  reg_key_id;
    logic [31:0] reg_nonce_domain;
    logic [63:0] reg_nonce_seed;
    logic [15:0] reg_payload_bytes;
    logic [31:0] reg_key_word [0:7];
    logic        key_dirty;

    // Mirrored AES GCM tag (read from AES 0x88-0x94 after each packet).
    logic [31:0] reg_tag_word [0:3];
    logic [31:0] reg_ghash_word [0:3];
    logic        tag_valid_flag;
    logic [31:0] mst_rd_data;

    logic [31:0] aes_status_last;

    logic slv_aw_seen;
    logic [C_AXI_ADDR_WIDTH-1:0] slv_awaddr;

    logic mst_wr_pending;
    logic mst_wr_done;
    logic [C_AXI_ADDR_WIDTH-1:0] mst_wr_addr;
    logic [C_AXI_DATA_WIDTH-1:0] mst_wr_data;
    logic mst_wr_launch;

    logic mst_rd_pending;
    logic mst_rd_done;

    logic s_axi_wr_fire;
    logic s_axi_wr_ctrl;
    logic s_axi_wr_key;
    logic req_apply_nonce_seed;
    logic req_key_dirty;

    assign nonce_counter_out = nonce_ctr;
    assign cfg_session_id = reg_session_id;
    assign cfg_stream_id = reg_stream_id;
    assign cfg_payload_type = reg_payload_type;
    assign cfg_key_id = reg_key_id;
    assign cfg_payload_bytes = reg_payload_bytes;
    assign cfg_nonce_counter = nonce_ctr;
    assign cfg_enable = reg_ctrl[0];
    assign seq_busy = (state != ST_IDLE) && (state != ST_PASS);

    assign s_axi_wr_fire = S_AXI_WREADY && S_AXI_WVALID;
    assign s_axi_wr_ctrl = s_axi_wr_fire && (slv_awaddr[7:0] == REG_CTRL);
    assign s_axi_wr_key  = s_axi_wr_fire && (slv_awaddr[7:0] >= REG_KEY0) && (slv_awaddr[7:0] <= REG_KEY7);
    assign req_apply_nonce_seed = s_axi_wr_ctrl && ((S_AXI_WDATA & CTRL_APPLY_NONCE_SEED) != 32'd0);
    assign req_key_dirty =
        (s_axi_wr_ctrl && (((S_AXI_WDATA & CTRL_FORCE_KEY_DIRTY) != 32'd0) || ((S_AXI_WDATA & CTRL_LOAD_KEY_REQ) != 32'd0))) ||
        s_axi_wr_key;

    // Pass-through: only when in ST_PASS or ST_WAIT_LAST
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tkeep  = s_axis_tkeep;
    assign m_axis_tlast  = s_axis_tlast;
    assign m_axis_tvalid = (state == ST_PASS) ? s_axis_tvalid : 1'b0;
    assign s_axis_tready = (state == ST_PASS) ? m_axis_tready : 1'b0;

    // AXI-Lite slave: PS configuration path.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            slv_aw_seen       <= 1'b0;
            slv_awaddr        <= '0;
            S_AXI_AWREADY     <= 1'b1;
            S_AXI_WREADY      <= 1'b0;
            S_AXI_BRESP       <= 2'b00;
            S_AXI_BVALID      <= 1'b0;
            S_AXI_ARREADY     <= 1'b1;
            S_AXI_RRESP       <= 2'b00;
            S_AXI_RVALID      <= 1'b0;
            S_AXI_RDATA       <= '0;

            reg_ctrl          <= CTRL_ENABLE;
            reg_session_id    <= DEFAULT_SESSION_ID;
            reg_stream_id     <= DEFAULT_STREAM_ID;
            reg_payload_type  <= DEFAULT_PAYLOAD_TYPE;
            reg_key_id        <= DEFAULT_KEY_ID;
            reg_nonce_domain  <= DEFAULT_NONCE_DOMAIN;
            reg_nonce_seed    <= DEFAULT_NONCE_SEED;
            reg_payload_bytes <= DEFAULT_PAYLOAD_BYTES;
            reg_key_word[0]   <= 32'h00000000;
            reg_key_word[1]   <= 32'h00000000;
            reg_key_word[2]   <= 32'h00000000;
            reg_key_word[3]   <= 32'h00000000;
            reg_key_word[4]   <= 32'h00000000;
            reg_key_word[5]   <= 32'h00000000;
            reg_key_word[6]   <= 32'h00000000;
            reg_key_word[7]   <= 32'h00000000;
        end else begin
            if (S_AXI_AWREADY && S_AXI_AWVALID) begin
                slv_aw_seen   <= 1'b1;
                slv_awaddr    <= S_AXI_AWADDR;
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b1;
            end

            if (S_AXI_WREADY && S_AXI_WVALID) begin
                case (slv_awaddr[7:0])
                    REG_CTRL: begin
                        reg_ctrl[0] <= S_AXI_WDATA[0];
                    end
                    REG_SESSION_ID: reg_session_id <= S_AXI_WDATA;
                    REG_STREAM_PAYLOAD: begin
                        reg_stream_id    <= S_AXI_WDATA[15:0];
                        reg_payload_type <= S_AXI_WDATA[23:16];
                        reg_key_id       <= S_AXI_WDATA[31:24];
                    end
                    REG_NONCE_DOMAIN: reg_nonce_domain <= S_AXI_WDATA;
                    REG_NONCE_SEED_HI: reg_nonce_seed[63:32] <= S_AXI_WDATA;
                    REG_NONCE_SEED_LO: reg_nonce_seed[31:0] <= S_AXI_WDATA;
                    REG_PAYLOAD_BYTES: reg_payload_bytes <= (S_AXI_WDATA[15:0] == 16'd0) ? DEFAULT_PAYLOAD_BYTES : S_AXI_WDATA[15:0];
                    REG_KEY0: reg_key_word[0] <= S_AXI_WDATA;
                    REG_KEY1: reg_key_word[1] <= S_AXI_WDATA;
                    REG_KEY2: reg_key_word[2] <= S_AXI_WDATA;
                    REG_KEY3: reg_key_word[3] <= S_AXI_WDATA;
                    REG_KEY4: reg_key_word[4] <= S_AXI_WDATA;
                    REG_KEY5: reg_key_word[5] <= S_AXI_WDATA;
                    REG_KEY6: reg_key_word[6] <= S_AXI_WDATA;
                    REG_KEY7: reg_key_word[7] <= S_AXI_WDATA;
                    default: begin end
                endcase

                S_AXI_WREADY  <= 1'b0;
                S_AXI_BVALID  <= 1'b1;
                S_AXI_AWREADY <= 1'b1;
                slv_aw_seen   <= 1'b0;
            end

            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

            if (S_AXI_ARREADY && S_AXI_ARVALID) begin
                case (S_AXI_ARADDR[7:0])
                    REG_CTRL: S_AXI_RDATA <= reg_ctrl;
                    REG_STATUS: S_AXI_RDATA <= {
                        12'd0,
                        aes_status_last[19:16],
                        3'd0,
                        key_dirty,
                        seq_busy,
                        cfg_enable,
                        aes_status_last[12:0]
                    };
                    REG_SESSION_ID: S_AXI_RDATA <= reg_session_id;
                    REG_STREAM_PAYLOAD: S_AXI_RDATA <= {reg_key_id, reg_payload_type, reg_stream_id};
                    REG_NONCE_DOMAIN: S_AXI_RDATA <= reg_nonce_domain;
                    REG_NONCE_SEED_HI: S_AXI_RDATA <= reg_nonce_seed[63:32];
                    REG_NONCE_SEED_LO: S_AXI_RDATA <= reg_nonce_seed[31:0];
                    REG_PAYLOAD_BYTES: S_AXI_RDATA <= {16'd0, reg_payload_bytes};
                    REG_KEY0: S_AXI_RDATA <= reg_key_word[0];
                    REG_KEY1: S_AXI_RDATA <= reg_key_word[1];
                    REG_KEY2: S_AXI_RDATA <= reg_key_word[2];
                    REG_KEY3: S_AXI_RDATA <= reg_key_word[3];
                    REG_KEY4: S_AXI_RDATA <= reg_key_word[4];
                    REG_KEY5: S_AXI_RDATA <= reg_key_word[5];
                    REG_KEY6: S_AXI_RDATA <= reg_key_word[6];
                    REG_KEY7: S_AXI_RDATA <= reg_key_word[7];
                    REG_NONCE_CUR_HI: S_AXI_RDATA <= nonce_ctr[63:32];
                    REG_NONCE_CUR_LO: S_AXI_RDATA <= nonce_ctr[31:0];
                    REG_VIDEO_BEAT_COUNT_HI:  S_AXI_RDATA <= dbg_video_beat_count[63:32];
                    REG_VIDEO_BEAT_COUNT_LO:  S_AXI_RDATA <= dbg_video_beat_count[31:0];
                    REG_VIDEO_FRAME_COUNT_HI: S_AXI_RDATA <= dbg_video_frame_count[63:32];
                    REG_VIDEO_FRAME_COUNT_LO: S_AXI_RDATA <= dbg_video_frame_count[31:0];
                    REG_PREFIFO_BEAT_HI: S_AXI_RDATA <= dbg_prefifo_beats[63:32];
                    REG_PREFIFO_BEAT_LO: S_AXI_RDATA <= dbg_prefifo_beats[31:0];
                    REG_TAG0: S_AXI_RDATA <= reg_tag_word[0];
                    REG_TAG1: S_AXI_RDATA <= reg_tag_word[1];
                    REG_TAG2: S_AXI_RDATA <= reg_tag_word[2];
                    REG_TAG3: S_AXI_RDATA <= reg_tag_word[3];
                    REG_GHASH0: S_AXI_RDATA <= reg_ghash_word[0];
                    REG_GHASH1: S_AXI_RDATA <= reg_ghash_word[1];
                    REG_GHASH2: S_AXI_RDATA <= reg_ghash_word[2];
                    REG_GHASH3: S_AXI_RDATA <= reg_ghash_word[3];
                    REG_TAG_VALID: S_AXI_RDATA <= {31'd0, tag_valid_flag};
                    REG_DBG_PUSH0: S_AXI_RDATA <= dbg_push_data[127:96];
                    REG_DBG_PUSH1: S_AXI_RDATA <= dbg_push_data[95:64];
                    REG_DBG_PUSH2: S_AXI_RDATA <= dbg_push_data[63:32];
                    REG_DBG_PUSH3: S_AXI_RDATA <= dbg_push_data[31:0];
                    REG_DBG_MAXIS0: S_AXI_RDATA <= dbg_maxis_last_beat[127:96];
                    REG_DBG_MAXIS1: S_AXI_RDATA <= dbg_maxis_last_beat[95:64];
                    REG_DBG_MAXIS2: S_AXI_RDATA <= dbg_maxis_last_beat[63:32];
                    REG_DBG_MAXIS3: S_AXI_RDATA <= dbg_maxis_last_beat[31:0];
                    REG_AES_STATUS: S_AXI_RDATA <= aes_status_last;
                    REG_DBG_CT_BEATS: S_AXI_RDATA <= dbg_ct_beats;
                    REG_DBG_TAG_PUSHES: S_AXI_RDATA <= dbg_tag_pushes;
                    REG_DBG_TAG_FIFO_COUNT: S_AXI_RDATA <= dbg_tag_fifo_count;
                    REG_DBG_TAG_PT_INFLIGHT: S_AXI_RDATA <= dbg_tag_pt_inflight;
                    REG_DBG_LAST_CT_BEATS: S_AXI_RDATA <= dbg_last_ct_beats;
                    REG_DBG_LAST_FIFO_PUSHES: S_AXI_RDATA <= dbg_last_fifo_pushes;
                    REG_DBG_LAST_AXIS_POPS: S_AXI_RDATA <= dbg_last_axis_pops;
                    REG_DBG_LAST_TAG_ATTEMPTS: S_AXI_RDATA <= dbg_last_tag_attempts;
                    REG_DBG_LAST_FIFO_COUNT: S_AXI_RDATA <= dbg_last_fifo_count;
                    default: S_AXI_RDATA <= 32'h00000000;
                endcase
                S_AXI_RVALID  <= 1'b1;
                S_AXI_ARREADY <= 1'b0;
            end

            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID  <= 1'b0;
                S_AXI_ARREADY <= 1'b1;
            end
        end
    end

    // AXI-Lite master write channel to AES.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            M_AXI_AWADDR    <= '0;
            M_AXI_AWPROT    <= 3'b000;
            M_AXI_AWVALID   <= 1'b0;
            M_AXI_WDATA     <= '0;
            M_AXI_WSTRB     <= 4'hF;
            M_AXI_WVALID    <= 1'b0;
            M_AXI_BREADY    <= 1'b0;
            mst_wr_pending   <= 1'b0;
            mst_wr_done      <= 1'b0;
        end else begin
            mst_wr_done <= 1'b0;
            if (mst_wr_launch && !mst_wr_pending) begin
                M_AXI_AWADDR  <= mst_wr_addr;
                M_AXI_AWVALID <= 1'b1;
                M_AXI_WDATA   <= mst_wr_data;
                M_AXI_WVALID  <= 1'b1;
                M_AXI_BREADY  <= 1'b1;
                mst_wr_pending <= 1'b1;
            end else begin
                if (M_AXI_AWVALID && M_AXI_AWREADY) M_AXI_AWVALID <= 1'b0;
                if (M_AXI_WVALID && M_AXI_WREADY)   M_AXI_WVALID <= 1'b0;
                if (M_AXI_BVALID && M_AXI_BREADY) begin
                    M_AXI_BREADY  <= 1'b0;
                    mst_wr_pending <= 1'b0;
                    mst_wr_done    <= 1'b1;
                end
            end
        end
    end

    // AXI-Lite master read channel from AES STATUS.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            M_AXI_ARADDR    <= AES_REG_STATUS;
            M_AXI_ARPROT    <= 3'b000;
            M_AXI_ARVALID   <= 1'b0;
            M_AXI_RREADY    <= 1'b0;
            mst_rd_pending  <= 1'b0;
            mst_rd_done     <= 1'b0;
        end else begin
            mst_rd_done <= 1'b0;

            if (!mst_rd_pending && (state == ST_POLL_KEYS || state == ST_POLL_SESSION || state == ST_WAIT_TAG)) begin
                M_AXI_ARADDR   <= AES_REG_STATUS;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_TAG0) begin
                M_AXI_ARADDR   <= AES_REG_TAG0;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_TAG1) begin
                M_AXI_ARADDR   <= AES_REG_TAG1;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_TAG2) begin
                M_AXI_ARADDR   <= AES_REG_TAG2;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_TAG3) begin
                M_AXI_ARADDR   <= AES_REG_TAG3;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_GHASH0) begin
                M_AXI_ARADDR   <= AES_REG_GHASH0;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_GHASH1) begin
                M_AXI_ARADDR   <= AES_REG_GHASH1;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_GHASH2) begin
                M_AXI_ARADDR   <= AES_REG_GHASH2;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else if (!mst_rd_pending && state == ST_RD_GHASH3) begin
                M_AXI_ARADDR   <= AES_REG_GHASH3;
                M_AXI_ARVALID  <= 1'b1;
                M_AXI_RREADY   <= 1'b1;
                mst_rd_pending <= 1'b1;
            end else begin
                if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                    M_AXI_ARVALID <= 1'b0;
                end
                if (M_AXI_RVALID && M_AXI_RREADY) begin
                    mst_rd_data <= M_AXI_RDATA;
                    if (state == ST_POLL_KEYS || state == ST_POLL_SESSION || state == ST_WAIT_TAG) begin
                        aes_status_last <= M_AXI_RDATA;
                    end
                    M_AXI_RREADY    <= 1'b0;
                    mst_rd_pending  <= 1'b0;
                    mst_rd_done     <= 1'b1;
                end
            end
        end
    end

    // Main FSM.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state       <= ST_IDLE;
            nonce_ctr   <= DEFAULT_NONCE_SEED;
            key_dirty   <= 1'b1;
            reg_tag_word[0] <= '0;
            reg_tag_word[1] <= '0;
            reg_tag_word[2] <= '0;
            reg_tag_word[3] <= '0;
            reg_ghash_word[0] <= '0;
            reg_ghash_word[1] <= '0;
            reg_ghash_word[2] <= '0;
            reg_ghash_word[3] <= '0;
            tag_valid_flag   <= 1'b0;
            mst_wr_addr <= '0;
            mst_wr_data <= '0;
            mst_wr_launch <= 1'b0;
        end else begin
            mst_wr_launch <= 1'b0;

            if (req_apply_nonce_seed) begin
                nonce_ctr <= reg_nonce_seed;
            end
            if (req_key_dirty) begin
                key_dirty <= 1'b1;
            end

            case (state)

                ST_IDLE: begin
                    if (!cfg_enable) begin
                        state <= ST_IDLE;
                    end else if (key_dirty) begin
                        // NOTE: removed the old "defensive recovery" branch that
                        // cleared key_dirty when the STALE aes_status_last mirror
                        // showed keys_ready. That mirror reflected the boot-time
                        // ZERO-key load, so the guard skipped loading the REAL key
                        // forever - the AES encrypted everything with the all-zeros
                        // key (verified on the wire: keystream matched key=0).
                        state <= ST_W_KEY0;
                    end else if (s_axis_tvalid) begin
                        state <= ST_W_NONCE0;
                    end
                end

                ST_W_KEY0: begin
                    mst_wr_addr   <= AES_REG_KEY0;
                    mst_wr_data   <= reg_key_word[0];
                    mst_wr_launch <= 1'b1;
                    state         <= ST_W_KEY1;
                end

                ST_W_KEY1: begin if (mst_wr_done) begin mst_wr_addr <= AES_REG_KEY0 + 8'h04; mst_wr_data <= reg_key_word[1]; mst_wr_launch <= 1'b1; state <= ST_W_KEY2; end end
                ST_W_KEY2: begin if (mst_wr_done) begin mst_wr_addr <= AES_REG_KEY0 + 8'h08; mst_wr_data <= reg_key_word[2]; mst_wr_launch <= 1'b1; state <= ST_W_KEY3; end end
                ST_W_KEY3: begin if (mst_wr_done) begin mst_wr_addr <= AES_REG_KEY0 + 8'h0C; mst_wr_data <= reg_key_word[3]; mst_wr_launch <= 1'b1; state <= ST_W_KEY4; end end
                ST_W_KEY4: begin if (mst_wr_done) begin mst_wr_addr <= AES_REG_KEY0 + 8'h10; mst_wr_data <= reg_key_word[4]; mst_wr_launch <= 1'b1; state <= ST_W_KEY5; end end
                ST_W_KEY5: begin if (mst_wr_done) begin mst_wr_addr <= AES_REG_KEY0 + 8'h14; mst_wr_data <= reg_key_word[5]; mst_wr_launch <= 1'b1; state <= ST_W_KEY6; end end
                ST_W_KEY6: begin if (mst_wr_done) begin mst_wr_addr <= AES_REG_KEY0 + 8'h18; mst_wr_data <= reg_key_word[6]; mst_wr_launch <= 1'b1; state <= ST_W_KEY7; end end
                ST_W_KEY7: begin if (mst_wr_done) begin mst_wr_addr <= AES_REG_KEY0 + 8'h1C; mst_wr_data <= reg_key_word[7]; mst_wr_launch <= 1'b1; state <= ST_W_LOAD_KEY; end end

                ST_W_LOAD_KEY: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_CTRL;
                        mst_wr_data   <= AES_CTRL_LOAD_KEY;
                        mst_wr_launch <= 1'b1;
                        state         <= ST_POLL_KEYS;
                    end
                end

                ST_POLL_KEYS: begin
                    if (mst_rd_done) begin
                        if ((aes_status_last & AES_STATUS_KEYS_READY) == AES_STATUS_KEYS_READY) begin
                            key_dirty <= 1'b0;
                            state <= ST_IDLE;
                        end
                    end
                end

                ST_W_NONCE0: begin
                    tag_valid_flag <= 1'b0;
                    mst_wr_addr   <= AES_REG_NONCE0;
                    mst_wr_data   <= reg_nonce_domain;
                    mst_wr_launch <= 1'b1;
                    state         <= ST_W_NONCE1;
                end

                ST_W_NONCE1: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_NONCE1;
                        mst_wr_data   <= nonce_ctr[63:32];
                        mst_wr_launch <= 1'b1;
                        state         <= ST_W_NONCE2;
                    end
                end

                ST_W_NONCE2: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_NONCE2;
                        mst_wr_data   <= nonce_ctr[31:0];
                        mst_wr_launch <= 1'b1;
                        state         <= ST_W_AAD_HI;
                    end
                end

                ST_W_AAD_HI: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_AAD_LEN_HI;
                        mst_wr_data   <= 32'd0;
                        mst_wr_launch <= 1'b1;
                        state         <= ST_W_AAD_LO;
                    end
                end

                ST_W_AAD_LO: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_AAD_LEN_LO;
                        mst_wr_data   <= 32'd0;
                        mst_wr_launch <= 1'b1;
                        state         <= ST_W_PT_HI;
                    end
                end

                ST_W_PT_HI: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_PT_LEN_HI;
                        mst_wr_data   <= (((HEADER_BYTES + reg_payload_bytes) * 8) >> 32);
                        mst_wr_launch <= 1'b1;
                        state         <= ST_W_PT_LO;
                    end
                end

                ST_W_PT_LO: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_PT_LEN_LO;
                        mst_wr_data   <= (((HEADER_BYTES + reg_payload_bytes) * 8) & 32'hFFFF_FFFF);
                        mst_wr_launch <= 1'b1;
                        state         <= ST_W_SET_STREAM;
                    end
                end

                ST_W_SET_STREAM: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_CTRL;
                        mst_wr_data   <= AES_CTRL_SET_STREAM;
                        mst_wr_launch <= 1'b1;
                        state         <= ST_W_START_SESS;
                    end
                end

                ST_W_START_SESS: begin
                    if (mst_wr_done) begin
                        mst_wr_addr   <= AES_REG_CTRL;
                        mst_wr_data   <= AES_CTRL_START_SESSION;
                        mst_wr_launch <= 1'b1;
                        state         <= ST_POLL_SESSION;
                    end
                end

                ST_POLL_SESSION: begin
                    if (mst_rd_done) begin
                        if ((aes_status_last & AES_STATUS_SESSION_RDY) != 32'd0) begin
                            state <= ST_PASS;
                        end
                    end
                end

                ST_PASS: begin
                    if (s_axis_tvalid && m_axis_tready && s_axis_tlast) begin
                        state     <= ST_WAIT_TAG;
                        nonce_ctr <= nonce_ctr + 1'b1;
                    end
                end

                ST_WAIT_TAG: begin
                    if (mst_rd_done) begin
                        if (aes_status_last[12]) begin
                            state <= ST_RD_TAG0;
                        end
                    end
                end

                ST_RD_TAG0: begin if (mst_rd_done) begin reg_tag_word[0] <= mst_rd_data; state <= ST_RD_TAG1; end end
                ST_RD_TAG1: begin if (mst_rd_done) begin reg_tag_word[1] <= mst_rd_data; state <= ST_RD_TAG2; end end
                ST_RD_TAG2: begin if (mst_rd_done) begin reg_tag_word[2] <= mst_rd_data; state <= ST_RD_TAG3; end end
                ST_RD_TAG3: begin
                    if (mst_rd_done) begin
                        reg_tag_word[3] <= mst_rd_data;
                        tag_valid_flag   <= 1'b1;
                        state            <= ST_RD_GHASH0;
                    end
                end

                ST_RD_GHASH0: begin if (mst_rd_done) begin reg_ghash_word[0] <= mst_rd_data; state <= ST_RD_GHASH1; end end
                ST_RD_GHASH1: begin if (mst_rd_done) begin reg_ghash_word[1] <= mst_rd_data; state <= ST_RD_GHASH2; end end
                ST_RD_GHASH2: begin if (mst_rd_done) begin reg_ghash_word[2] <= mst_rd_data; state <= ST_RD_GHASH3; end end
                ST_RD_GHASH3: begin
                    if (mst_rd_done) begin
                        reg_ghash_word[3] <= mst_rd_data;
                        state              <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;

            endcase
        end
    end

endmodule
