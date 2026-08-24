`timescale 1ns / 1ps
// tb_fullchain - packetizer -> sequencer -> AES full-chain check.
// Feeds 4 synthetic 720p frames and watches the AES's ciphertext stream:
//   - every beat TKEEP == 0xFFFF
//   - exactly 77 beats per packet (76 CT + 1 tag), tlast on the tag beat
//   - 4704 packets (2 captured frames x 2352 segments)
// Also flags the sequencer's inter-packet behavior at the full back-to-back
// rate (the first time it runs without the old 200k-cycle pacer).
module tb_fullchain;

    localparam int FRAME_PX = 1280 * 720;
    localparam int FRAMES   = 4;
    localparam int SEGS     = 2352;
    localparam int TARGET_PKTS = 100;

    logic clk = 0; always #5 clk = ~clk;
    logic rstn = 0;

    // ---- packetizer ----
    logic [23:0] px_data = '0;
    logic        px_valid = 0;
    logic        px_ready;
    logic        px_last = 0;
    logic        px_user = 0;
    logic [127:0] pkt_tdata;
    logic [15:0]  pkt_tkeep;
    logic         pkt_tvalid;
    logic         pkt_tready;
    logic         pkt_tlast;

    // ---- sequencer ----
    logic [127:0] seq_m_tdata;
    logic [15:0]  seq_m_tkeep;
    logic         seq_m_tvalid;
    logic         seq_m_tready;
    logic         seq_m_tlast;
    logic [7:0]   s_axi_awaddr;  logic [2:0] s_axi_awprot; logic s_axi_awvalid; logic s_axi_awready;
    logic [31:0]  s_axi_wdata;   logic [3:0] s_axi_wstrb;   logic s_axi_wvalid;  logic s_axi_wready;
    logic [1:0]   s_axi_bresp;   logic s_axi_bvalid; logic s_axi_bready;
    logic [7:0]   s_axi_araddr;  logic [2:0] s_axi_arprot; logic s_axi_arvalid; logic s_axi_arready;
    logic [31:0]  s_axi_rdata;   logic [1:0] s_axi_rresp;  logic s_axi_rvalid;  logic s_axi_rready;
    logic [7:0]   m_axi_awaddr;  logic [2:0] m_axi_awprot; logic m_axi_awvalid; logic m_axi_awready;
    logic [31:0]  m_axi_wdata;   logic [3:0] m_axi_wstrb;  logic m_axi_wvalid;  logic m_axi_wready;
    logic [1:0]   m_axi_bresp;   logic m_axi_bvalid; logic m_axi_bready;
    logic [7:0]   m_axi_araddr;  logic [2:0] m_axi_arprot; logic m_axi_arvalid; logic m_axi_arready;
    logic [31:0]  m_axi_rdata;   logic [1:0] m_axi_rresp;  logic m_axi_rvalid;  logic m_axi_rready;
    logic [31:0]  cfg_session_id, cfg_payload_type_x, cfg_nonce_counter_hi;
    logic [15:0]  cfg_stream_id, cfg_payload_bytes;
    logic [7:0]   cfg_payload_type, cfg_key_id;
    logic [63:0]  cfg_nonce_counter;
    logic         cfg_enable;
    logic [63:0]  dbg_beats, dbg_frames;
    logic [127:0] dbg_push, dbg_maxis;

    // ---- AES ----
    logic [127:0] ct_tdata;
    logic [15:0]  ct_tkeep;
    logic         ct_tvalid;
    logic         ct_tready;
    logic         ct_tlast;

    // ---- nonce prefix injector ----------------
    logic [63:0]  pkt_nonce;
    logic [127:0] inj_tdata;
    logic [15:0]  inj_tkeep;
    logic         inj_tvalid;
    logic         inj_tready;
    logic         inj_tlast;
    logic         aes_stream_empty;

    // ---- B.2 DDR ring writer composition model ---------------------------
    localparam integer B2_RING_LOG2 = 4;
    localparam integer B2_RING_SLOTS = 1 << B2_RING_LOG2;
    localparam integer B2_SLOT_STRIDE = 1280;
    localparam [31:0] B2_RING_BASE = 32'h1000_0000;
    localparam [31:0] B2_CTRL_BASE = 32'h2000_0000;

    logic [7:0]  ring_s_axi_awaddr;
    logic [2:0]  ring_s_axi_awprot = '0;
    logic        ring_s_axi_awvalid = 1'b0, ring_s_axi_awready;
    logic [31:0] ring_s_axi_wdata;
    logic [3:0]  ring_s_axi_wstrb = 4'hF;
    logic        ring_s_axi_wvalid = 1'b0, ring_s_axi_wready;
    logic [1:0]  ring_s_axi_bresp;
    logic        ring_s_axi_bvalid, ring_s_axi_bready = 1'b0;
    logic [7:0]  ring_s_axi_araddr;
    logic [2:0]  ring_s_axi_arprot = '0;
    logic        ring_s_axi_arvalid = 1'b0, ring_s_axi_arready;
    logic [31:0] ring_s_axi_rdata;
    logic [1:0]  ring_s_axi_rresp;
    logic        ring_s_axi_rvalid, ring_s_axi_rready = 1'b0;

    logic [31:0] ring_m_axi_awaddr;
    logic [7:0]  ring_m_axi_awlen;
    logic [2:0]  ring_m_axi_awsize;
    logic [1:0]  ring_m_axi_awburst;
    logic        ring_m_axi_awvalid, ring_m_axi_awready = 1'b1;
    logic [63:0] ring_m_axi_wdata;
    logic [7:0]  ring_m_axi_wstrb;
    logic        ring_m_axi_wlast;
    logic        ring_m_axi_wvalid, ring_m_axi_wready = 1'b1;
    logic [1:0]  ring_m_axi_bresp = 2'b00;
    logic        ring_m_axi_bvalid = 1'b0, ring_m_axi_bready;
    logic [31:0] ring_m_axi_araddr;
    logic [2:0]  ring_m_axi_arprot;
    logic        ring_m_axi_arvalid, ring_m_axi_arready = 1'b1;
    logic [31:0] ring_m_axi_rdata;
    logic [1:0]  ring_m_axi_rresp = 2'b00;
    logic        ring_m_axi_rvalid = 1'b0, ring_m_axi_rready;
    logic        ring_axis_ready;
    logic        ring_irq;

    logic [7:0] ring_mem [0:B2_RING_SLOTS*B2_SLOT_STRIDE-1];
    logic [31:0] ring_ctrl_consume = 0;
    logic [31:0] ring_ctrl_produce = 0;
    logic        ring_aw_seen = 1'b0;
    logic [31:0] ring_write_addr;
    integer ring_write_beats_left = 0;
    integer ring_publish_count = 0;
    integer ring_ctrl_read_count = 0;
    integer ring_mem_errors = 0;
    integer ring_axi_boundary_errors = 0;
    integer ring_slot_geometry_errors = 0;
    integer ring_data_burst_count = 0;
    integer ring_last_packet [0:B2_RING_SLOTS-1];

    HDMI_Axis_Packetizer pkt (
        .aclk(clk), .aresetn(rstn),
        .s_axis_video_tdata(px_data), .s_axis_video_tvalid(px_valid),
        .s_axis_video_tready(px_ready), .s_axis_video_tlast(px_last),
        .s_axis_video_tuser(px_user),
        .cfg_session_id(cfg_session_id), .cfg_stream_id(cfg_stream_id),
        .cfg_payload_type(cfg_payload_type), .cfg_key_id(cfg_key_id),
        .cfg_payload_bytes(cfg_payload_bytes), .cfg_nonce_counter(cfg_nonce_counter),
        .cfg_enable(cfg_enable),
        .dbg_video_beat_count(dbg_beats), .dbg_video_frame_count(dbg_frames),
        .m_axis_pkt_tdata(pkt_tdata), .m_axis_pkt_tkeep(pkt_tkeep),
        .m_axis_pkt_tvalid(pkt_tvalid), .m_axis_pkt_tready(pkt_tready),
        .m_axis_pkt_tlast(pkt_tlast)
    );

    AES_GCM_Session_Sequencer seq (
        .aclk(clk), .aresetn(rstn),
        .s_axis_tdata(pkt_tdata), .s_axis_tkeep(pkt_tkeep),
        .s_axis_tvalid(pkt_tvalid), .s_axis_tready(pkt_tready),
        .s_axis_tlast(pkt_tlast),
        .m_axis_tdata(seq_m_tdata), .m_axis_tkeep(seq_m_tkeep),
        .m_axis_tvalid(seq_m_tvalid), .m_axis_tready(seq_m_tready),
        .m_axis_tlast(seq_m_tlast),
        .S_AXI_AWADDR(s_axi_awaddr), .S_AXI_AWPROT(s_axi_awprot),
        .S_AXI_AWVALID(s_axi_awvalid), .S_AXI_AWREADY(s_axi_awready),
        .S_AXI_WDATA(s_axi_wdata), .S_AXI_WSTRB(s_axi_wstrb),
        .S_AXI_WVALID(s_axi_wvalid), .S_AXI_WREADY(s_axi_wready),
        .S_AXI_BRESP(s_axi_bresp), .S_AXI_BVALID(s_axi_bvalid), .S_AXI_BREADY(s_axi_bready),
        .S_AXI_ARADDR(s_axi_araddr), .S_AXI_ARPROT(s_axi_arprot),
        .S_AXI_ARVALID(s_axi_arvalid), .S_AXI_ARREADY(s_axi_arready),
        .S_AXI_RDATA(s_axi_rdata), .S_AXI_RRESP(s_axi_rresp),
        .S_AXI_RVALID(s_axi_rvalid), .S_AXI_RREADY(s_axi_rready),
        .M_AXI_AWADDR(m_axi_awaddr), .M_AXI_AWPROT(m_axi_awprot),
        .M_AXI_AWVALID(m_axi_awvalid), .M_AXI_AWREADY(m_axi_awready),
        .M_AXI_WDATA(m_axi_wdata), .M_AXI_WSTRB(m_axi_wstrb),
        .M_AXI_WVALID(m_axi_wvalid), .M_AXI_WREADY(m_axi_wready),
        .M_AXI_BRESP(m_axi_bresp), .M_AXI_BVALID(m_axi_bvalid), .M_AXI_BREADY(m_axi_bready),
        .M_AXI_ARADDR(m_axi_araddr), .M_AXI_ARPROT(m_axi_arprot),
        .M_AXI_ARVALID(m_axi_arvalid), .M_AXI_ARREADY(m_axi_arready),
        .M_AXI_RDATA(m_axi_rdata), .M_AXI_RRESP(m_axi_rresp),
        .M_AXI_RVALID(m_axi_rvalid), .M_AXI_RREADY(m_axi_rready),
        .cfg_session_id(cfg_session_id), .cfg_stream_id(cfg_stream_id),
        .cfg_payload_type(cfg_payload_type), .cfg_key_id(cfg_key_id),
        .cfg_payload_bytes(cfg_payload_bytes), .cfg_nonce_counter(cfg_nonce_counter),
        .cfg_enable(cfg_enable),
        .pkt_nonce(pkt_nonce),
        .aes_stream_empty(aes_stream_empty),
        .dbg_video_beat_count(dbg_beats), .dbg_video_frame_count(dbg_frames),
        .dbg_prefifo_beats(64'd0),
        .dbg_push_data(dbg_push), .dbg_maxis_last_beat(dbg_maxis)
    );

    AXI_AES_GCM_Stream aes (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rstn),
        .S_AXI_AWADDR(m_axi_awaddr), .S_AXI_AWPROT(m_axi_awprot),
        .S_AXI_AWVALID(m_axi_awvalid), .S_AXI_AWREADY(m_axi_awready),
        .S_AXI_WDATA(m_axi_wdata), .S_AXI_WSTRB(m_axi_wstrb),
        .S_AXI_WVALID(m_axi_wvalid), .S_AXI_WREADY(m_axi_wready),
        .S_AXI_BRESP(m_axi_bresp), .S_AXI_BVALID(m_axi_bvalid), .S_AXI_BREADY(m_axi_bready),
        .S_AXI_ARADDR(m_axi_araddr), .S_AXI_ARPROT(m_axi_arprot),
        .S_AXI_ARVALID(m_axi_arvalid), .S_AXI_ARREADY(m_axi_arready),
        .S_AXI_RDATA(m_axi_rdata), .S_AXI_RRESP(m_axi_rresp),
        .S_AXI_RVALID(m_axi_rvalid), .S_AXI_RREADY(m_axi_rready),
        .S_AXIS_PT_TDATA(seq_m_tdata), .S_AXIS_PT_TKEEP(seq_m_tkeep),
        .S_AXIS_PT_TLAST(seq_m_tlast), .S_AXIS_PT_TVALID(seq_m_tvalid),
        .S_AXIS_PT_TREADY(seq_m_tready),
        .M_AXIS_CT_TDATA(ct_tdata), .M_AXIS_CT_TKEEP(ct_tkeep),
        .M_AXIS_CT_TLAST(ct_tlast), .M_AXIS_CT_TVALID(ct_tvalid),
        .M_AXIS_CT_TREADY(ct_tready),
        .stream_empty(aes_stream_empty),
        .dbg_push_data(dbg_push), .dbg_maxis_last_beat(dbg_maxis)
    );

    // Nonce prefix injector: AES CT -> (8B nonce prefix) + CT, per packet.
    NoncePrefixInject inj (
        .aclk(clk), .aresetn(rstn),
        .s_axis_tdata(ct_tdata), .s_axis_tkeep(ct_tkeep),
        .s_axis_tvalid(ct_tvalid), .s_axis_tready(ct_tready),
        .s_axis_tlast(ct_tlast),
        .pkt_nonce(pkt_nonce),
        .m_axis_tdata(inj_tdata), .m_axis_tkeep(inj_tkeep),
        .m_axis_tvalid(inj_tvalid), .m_axis_tready(inj_tready),
        .m_axis_tlast(inj_tlast)
    );

    DDRRingWriter #(
        .PACKET_BYTES(1240), .SLOT_STRIDE(B2_SLOT_STRIDE),
        .RING_LOG2(B2_RING_LOG2)
    ) ring_writer (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rstn),
        .S_AXI_AWADDR(ring_s_axi_awaddr), .S_AXI_AWPROT(ring_s_axi_awprot),
        .S_AXI_AWVALID(ring_s_axi_awvalid), .S_AXI_AWREADY(ring_s_axi_awready),
        .S_AXI_WDATA(ring_s_axi_wdata), .S_AXI_WSTRB(ring_s_axi_wstrb),
        .S_AXI_WVALID(ring_s_axi_wvalid), .S_AXI_WREADY(ring_s_axi_wready),
        .S_AXI_BRESP(ring_s_axi_bresp), .S_AXI_BVALID(ring_s_axi_bvalid),
        .S_AXI_BREADY(ring_s_axi_bready), .S_AXI_ARADDR(ring_s_axi_araddr),
        .S_AXI_ARPROT(ring_s_axi_arprot), .S_AXI_ARVALID(ring_s_axi_arvalid),
        .S_AXI_ARREADY(ring_s_axi_arready), .S_AXI_RDATA(ring_s_axi_rdata),
        .S_AXI_RRESP(ring_s_axi_rresp), .S_AXI_RVALID(ring_s_axi_rvalid),
        .S_AXI_RREADY(ring_s_axi_rready),
        .M_AXI_AWADDR(ring_m_axi_awaddr), .M_AXI_AWLEN(ring_m_axi_awlen),
        .M_AXI_AWSIZE(ring_m_axi_awsize), .M_AXI_AWBURST(ring_m_axi_awburst),
        .M_AXI_AWVALID(ring_m_axi_awvalid), .M_AXI_AWREADY(ring_m_axi_awready),
        .M_AXI_WDATA(ring_m_axi_wdata), .M_AXI_WSTRB(ring_m_axi_wstrb),
        .M_AXI_WLAST(ring_m_axi_wlast), .M_AXI_WVALID(ring_m_axi_wvalid),
        .M_AXI_WREADY(ring_m_axi_wready), .M_AXI_BRESP(ring_m_axi_bresp),
        .M_AXI_BVALID(ring_m_axi_bvalid), .M_AXI_BREADY(ring_m_axi_bready),
        .M_AXI_ARADDR(ring_m_axi_araddr), .M_AXI_ARPROT(ring_m_axi_arprot),
        .M_AXI_ARVALID(ring_m_axi_arvalid), .M_AXI_ARREADY(ring_m_axi_arready),
        .M_AXI_RDATA(ring_m_axi_rdata), .M_AXI_RRESP(ring_m_axi_rresp),
        .M_AXI_RVALID(ring_m_axi_rvalid), .M_AXI_RREADY(ring_m_axi_rready),
        .S_AXIS_TDATA(inj_tdata), .S_AXIS_TKEEP(inj_tkeep),
        .S_AXIS_TLAST(inj_tlast), .S_AXIS_TVALID(inj_tvalid),
        .S_AXIS_TREADY(ring_axis_ready), .irq(ring_irq)
    );
    assign inj_tready = ring_axis_ready && (ring_publish_count < TARGET_PKTS);

    // B.2 AXI memory/control-block model. The model consumes each published
    // produce index immediately, so the 16-slot ring never fills in this
    // composition test. Slot contents are checked after all 100 packets.
    always @(posedge clk) begin
        if (!rstn) begin
            ring_m_axi_bvalid <= 1'b0;
            ring_m_axi_rvalid <= 1'b0;
            ring_aw_seen <= 1'b0;
            ring_write_beats_left <= 0;
        end else begin
            if (ring_m_axi_awvalid && ring_m_axi_awready) begin
                integer burst_bytes;
                integer slot_offset;
                burst_bytes = (ring_m_axi_awlen + 1) * 8;
                if (ring_m_axi_awaddr >= B2_RING_BASE &&
                    ring_m_axi_awaddr < B2_RING_BASE + B2_RING_SLOTS*B2_SLOT_STRIDE) begin
                    slot_offset = (ring_m_axi_awaddr - B2_RING_BASE) % B2_SLOT_STRIDE;
                    if (((ring_m_axi_awaddr & 32'h00000FFF) + burst_bytes) > 4096)
                        ring_axi_boundary_errors = ring_axi_boundary_errors + 1;
                    if ((slot_offset + burst_bytes) > B2_SLOT_STRIDE ||
                        ring_m_axi_awlen != 8'd15)
                        ring_slot_geometry_errors = ring_slot_geometry_errors + 1;
                    ring_data_burst_count = ring_data_burst_count + 1;
                end
                ring_aw_seen <= 1'b1;
                ring_write_addr <= ring_m_axi_awaddr;
                ring_write_beats_left <= ring_m_axi_awlen + 1;
            end
            if (ring_m_axi_wvalid && ring_m_axi_wready) begin
                if (!ring_aw_seen || ring_write_beats_left <= 0) begin
                    ring_mem_errors = ring_mem_errors + 1;
                end else if (ring_write_addr >= B2_RING_BASE &&
                             ring_write_addr < B2_RING_BASE + B2_RING_SLOTS*B2_SLOT_STRIDE) begin
                    for (integer b = 0; b < 8; b = b + 1)
                        if (ring_m_axi_wstrb[b])
                            ring_mem[ring_write_addr-B2_RING_BASE+b] = ring_m_axi_wdata[8*b +: 8];
                end else if (ring_write_addr == B2_CTRL_BASE) begin
                    ring_ctrl_produce = ring_m_axi_wdata[31:0];
                    ring_ctrl_consume = ring_ctrl_produce;
                    if (ring_publish_count < TARGET_PKTS)
                        ring_last_packet[(ring_ctrl_produce == 0) ? B2_RING_SLOTS-1 : (ring_ctrl_produce-1) & (B2_RING_SLOTS-1)] = ring_publish_count;
                    ring_publish_count = ring_publish_count + 1;
                end else begin
                    ring_mem_errors = ring_mem_errors + 1;
                end
                ring_write_addr <= ring_write_addr + 8;
                ring_write_beats_left <= ring_write_beats_left - 1;
                if (ring_m_axi_wlast) begin
                    ring_aw_seen <= 1'b0;
                    ring_m_axi_bvalid <= 1'b1;
                end
            end
            if (ring_m_axi_bvalid && ring_m_axi_bready)
                ring_m_axi_bvalid <= 1'b0;
            if (ring_m_axi_arvalid && ring_m_axi_arready) begin
                if (ring_m_axi_araddr == B2_CTRL_BASE + 4) begin
                    ring_m_axi_rdata <= ring_ctrl_consume;
                    ring_ctrl_read_count = ring_ctrl_read_count + 1;
                end else begin
                    ring_m_axi_rdata <= 32'hDEAD_BEEF;
                end
                ring_m_axi_rvalid <= 1'b1;
            end
            if (ring_m_axi_rvalid && ring_m_axi_rready)
                ring_m_axi_rvalid <= 1'b0;
        end
    end

    task ring_axi_write(input [7:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            ring_s_axi_awaddr = addr;
            ring_s_axi_wdata = data;
            ring_s_axi_awvalid = 1'b1;
            ring_s_axi_wvalid = 1'b1;
            while (!(ring_s_axi_awready && ring_s_axi_wready)) @(posedge clk);
            @(negedge clk);
            ring_s_axi_awvalid = 1'b0;
            ring_s_axi_wvalid = 1'b0;
            ring_s_axi_bready = 1'b1;
            while (!ring_s_axi_bvalid) @(posedge clk);
            @(posedge clk);
            @(negedge clk);
            ring_s_axi_bready = 1'b0;
        end
    endtask

    // ---- AXI-Lite master tasks (the sequencer's config port) ----
    task axi_write(input [7:0] addr, input [31:0] data);
        begin
            // Drive on the falling edge. Hold VALID until the DUT samples
            // the handshake on a rising edge; do not use a level-only wait
            // because AWREADY is already high before the first handshake.
            @(negedge clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = data;
            s_axi_wstrb   = 4'hF;
            s_axi_wvalid  = 1'b1;

            while (1) begin
                @(posedge clk);
                if (s_axi_awready) begin
                    @(negedge clk);
                    s_axi_awvalid = 1'b0;
                    break;
                end
            end

            while (1) begin
                @(posedge clk);
                if (s_axi_wready) begin
                    @(negedge clk);
                    s_axi_wvalid = 1'b0;
                    break;
                end
            end

            while (!s_axi_bvalid)
                @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b0;
        end
    endtask

    // ---- the handshake feeder (same as tb_packetizer) ----
    reg [1:0]  feed_f;
    reg [19:0] feed_i;
    reg        feed_active;

    always @(posedge clk) begin
        logic [19:0] nxt_i;
        nxt_i = feed_i + 1'b1;
        if (!rstn) begin
            feed_active <= 1'b0;
            feed_f <= '0;
            feed_i <= '0;
            px_valid <= 1'b0;
            px_user <= 1'b0;
            px_data <= '0;
        end else if (feed_active && px_valid && px_ready) begin
            if (feed_i == FRAME_PX-1) begin
                if (feed_f == FRAMES-1) begin
                    feed_active <= 1'b0;
                    px_valid <= 1'b0;
                    px_user <= 1'b0;
                end else begin
                    feed_f <= feed_f + 1'b1;
                    feed_i <= '0;
                    px_user <= 1'b1;
                    px_data <= {6'd0, feed_f + 1'b1, 8'd0, 8'd0};
                end
            end else begin
                feed_i <= nxt_i;
                px_user <= 1'b0;
                px_data <= {6'd0, feed_f, nxt_i[7:0], nxt_i[15:8]};
            end
        end else if (!feed_active) begin
            feed_active <= 1'b1;
            px_valid <= 1'b1;
            px_user <= 1'b1;
            px_data <= {8'd0, 8'd0, 8'd0};
        end
    end

    // The AXI-Lite task above is the only stimulus driver. Keep this test
    // bench quiet; a per-cycle slave print made a stalled run generate
    // tens of megabytes and hid the real failure point.

    // ---- the CT sink checks ----
    int errors = 0;
    int tlast_total = 0;
    int beats_in_pkt = 0;
    longint beats_total = 0;
    int first_stall = -1;

    int stall_cycles = 0;

    always @(posedge clk) begin
        if (!rstn) begin
            beats_in_pkt <= 0;
        end else if (ct_tvalid && ct_tready) begin
            beats_total = beats_total + 1;
            if (ct_tkeep != 16'hFFFF) begin
                errors++;
                if (errors < 8)
                    $display("T%0t bad TKEEP=%h beat=%0d", $time, ct_tkeep, beats_total);
            end
            beats_in_pkt <= beats_in_pkt + 1;
            if (ct_tlast) begin
                if (beats_in_pkt + 1 != 77) begin
                    errors++;
                    if (errors < 8)
                        $display("T%0t packet beat count bad: %0d (pkt %0d)", $time, beats_in_pkt + 1, tlast_total);
                end
                tlast_total = tlast_total + 1;
                beats_in_pkt <= 0;
            end
        end
        // the stall detector: the packetizer's video tready stuck low while
        // the video is flowing
        if (feed_active && px_valid && !px_ready && first_stall < 0 && rstn) begin
            if (stall_cycles > 1000) begin
                first_stall = $time;
                $display("T%0t STALL: video tready low with data valid", $time);
            end
        end
    end

    always @(posedge clk) begin
        if (!rstn) stall_cycles <= 0;
        else if (feed_active && px_valid && !px_ready) stall_cycles <= stall_cycles + 1;
        else stall_cycles <= 0;
    end

    // ---- nonce-prefix injector checks ----
    int inj_errors = 0;
    int inj_pkt_index = 0;
    int inj_beats_in_pkt = 0;
    longint inj_beats_total = 0;
    longint inj_tlast_total = 0;
    logic [63:0] exp_nonce;
    logic [7:0] raw_bytes [0:TARGET_PKTS*1232-1];
    logic [7:0] inj_bytes [0:TARGET_PKTS*1240-1];
    integer raw_capture_bytes = 0;
    integer raw_capture_packets = 0;
    integer inj_capture_bytes = 0;
    integer inj_capture_packets = 0;
    longint inj_stall_cycles = 0;

    always @(posedge clk) begin
        if (!rstn) begin
            inj_beats_in_pkt <= 0;
        end else if (ct_tvalid && ct_tready && raw_capture_packets < TARGET_PKTS) begin
            for (int j = 0; j < 16; j++) begin
                if (ct_tkeep[j] && raw_capture_bytes < TARGET_PKTS*1232) begin
                    raw_bytes[raw_capture_bytes] = ct_tdata[8*j +: 8];
                    raw_capture_bytes = raw_capture_bytes + 1;
                end
            end
            if (ct_tlast)
                raw_capture_packets = raw_capture_packets + 1;
        end
    end

    always @(posedge clk) begin
        if (rstn && inj_tvalid && inj_tready && inj_capture_packets < TARGET_PKTS) begin
            for (int j = 0; j < 16; j++) begin
                if (inj_tkeep[j] && inj_capture_bytes < TARGET_PKTS*1240) begin
                    inj_bytes[inj_capture_bytes] = inj_tdata[8*j +: 8];
                    inj_capture_bytes = inj_capture_bytes + 1;
                end
            end
            if (inj_tlast)
                inj_capture_packets = inj_capture_packets + 1;
        end
    end
    always @(posedge clk) begin
        if (rstn && inj_tvalid && !inj_tready)
            inj_stall_cycles = inj_stall_cycles + 1;
    end

    always @(posedge clk) begin
        if (rstn && inj_tvalid && inj_tready) begin
            inj_beats_total = inj_beats_total + 1;
            if (inj_beats_in_pkt == 0) begin
                // ---- prefix beat: 8 nonce bytes, big-endian, TKEEP=0x00FF ----
                exp_nonce = 64'd1 + inj_pkt_index;
                if (inj_tkeep != 16'h00FF) begin
                    inj_errors++;
                    if (inj_errors < 8)
                        $display("T%0t INJ prefix TKEEP=%h (want 00FF) pkt=%0d", $time, inj_tkeep, inj_pkt_index);
                end
                if (inj_tlast) begin
                    inj_errors++;
                    if (inj_errors < 8)
                        $display("T%0t INJ prefix TLAST=1 (want 0) pkt=%0d", $time, inj_pkt_index);
                end
                for (int j = 0; j < 8; j++) begin
                    if (inj_tdata[8*j +: 8] !== exp_nonce[(63 - 8*j) -: 8]) begin
                        inj_errors++;
                        if (inj_errors < 8)
                            $display("T%0t INJ prefix byte%0d=%h (want %h) pkt=%0d",
                                     $time, j, inj_tdata[8*j +: 8], exp_nonce[(63-8*j)-:8], inj_pkt_index);
                    end
                end
            end else begin
                // ---- CT beat: full TKEEP and same-cycle byte pass-through ----
                if (inj_tkeep != 16'hFFFF) begin
                    inj_errors++;
                    if (inj_errors < 8)
                        $display("T%0t INJ CT TKEEP=%h beat=%0d pkt=%0d", $time, inj_tkeep, inj_beats_in_pkt, inj_pkt_index);
                end
                if (!(ct_tvalid && ct_tready) || inj_tdata !== ct_tdata ||
                    inj_tkeep !== ct_tkeep || inj_tlast !== ct_tlast) begin
                    inj_errors++;
                    if (inj_errors < 8)
                        $display("T%0t INJ CT mismatch beat=%0d pkt=%0d inj=%h/%h/%0d raw=%h/%h/%0d",
                                 $time, inj_beats_in_pkt, inj_pkt_index,
                                 inj_tdata, inj_tkeep, inj_tlast,
                                 ct_tdata, ct_tkeep, ct_tlast);
                end
            end
            inj_beats_in_pkt <= inj_beats_in_pkt + 1;
            if (inj_tlast) begin
                if (inj_beats_in_pkt + 1 != 78) begin
                    inj_errors++;
                    if (inj_errors < 8)
                        $display("T%0t INJ packet beat count bad: %0d (pkt %0d)", $time, inj_beats_in_pkt + 1, inj_pkt_index);
                end
                inj_tlast_total = inj_tlast_total + 1;
                inj_pkt_index = inj_pkt_index + 1;
                inj_beats_in_pkt <= 0;
            end
        end
    end

    // ---- the config + the run ----
    integer i;
    reg [31:0] key_words [0:7];
    initial begin
        key_words[0]=32'h00010203; key_words[1]=32'h04050607;
        key_words[2]=32'h08090a0b; key_words[3]=32'h0c0d0e0f;
        key_words[4]=32'h10111213; key_words[5]=32'h14151617;
        key_words[6]=32'h18191a1b; key_words[7]=32'h1c1d1e1f;

        for (integer slot = 0; slot < B2_RING_SLOTS; slot = slot + 1)
            ring_last_packet[slot] = -1;
        rstn = 0;
        s_axi_awaddr = '0; s_axi_awprot = '0; s_axi_awvalid = 1'b0;
        s_axi_wdata = '0; s_axi_wstrb = 4'hF; s_axi_wvalid = 1'b0;
        s_axi_bready = 1'b0;
        s_axi_araddr = '0; s_axi_arprot = '0; s_axi_arvalid = 1'b0;
        s_axi_rready = 1'b0;
        repeat (10) @(posedge clk);
        rstn = 1;
        repeat (5) @(posedge clk);

        // Configure B.2 ring before enabling the B.1/AES producer.
        ring_axi_write(8'h0C, B2_RING_BASE);
        ring_axi_write(8'h14, B2_CTRL_BASE);
        ring_axi_write(8'h04, 32'h00000001);
        $display("T%0t B2 RING CONFIGURED", $time);
        $display("T%0t CONFIG START", $time);

        // the daemon's configure() + the key load + the shim's enable
        axi_write(8'h08, 32'h00000001);                    // REG_SESSION_ID
        $display("T%0t CONFIG session_id done", $time);
        axi_write(8'h0C, (32'h01 << 24) | (32'h01 << 16) | 32'h0001); // REG_STREAM_PAYLOAD
        axi_write(8'h10, 32'h00000001);                    // REG_NONCE_DOMAIN
        axi_write(8'h14, 32'h00000000);                    // REG_NONCE_SEED_HI
        axi_write(8'h18, 32'h00000001);                    // REG_NONCE_SEED_LO
        axi_write(8'h1C, 32'd1176);                        // REG_PAYLOAD_BYTES
        axi_write(8'h00, 32'h00000000);                    // CTRL = 0 (configure-only)
        for (i = 0; i < 8; i = i + 1)
            axi_write(8'h20 + i*4, key_words[i]);          // REG_KEY0-7
        axi_write(8'h00, 32'h00000002);                    // CTRL = LOAD_KEY_REQ
        axi_write(8'h00, 32'h00000004);                    // CTRL = APPLY_NONCE_SEED
        axi_write(8'h00, 32'h00000001);                    // CTRL = enable (the shim)
        $display("T%0t CONFIG enable done, starting the run", $time);

        // B.1 acceptance run: stop after the first 100 complete packets.
        // The feeder still supplies the normal video stream; $finish below
        // ends the run at this exact packet boundary.
        fork
            begin
                wait (inj_tlast_total >= TARGET_PKTS);
                wait (ring_publish_count >= TARGET_PKTS);
                #5000;
                disable b1_watchdog;
                $display("DONE beats=%0d tlasts=%0d (expect %0d) errors=%0d first_stall=%0d",
                         beats_total, tlast_total, TARGET_PKTS, errors, first_stall);
                $display("DONE inj_beats=%0d inj_tlasts=%0d (expect %0d) inj_errors=%0d",
                         inj_beats_total, inj_tlast_total, TARGET_PKTS, inj_errors);
                if (raw_capture_bytes != TARGET_PKTS*1232 ||
                    inj_capture_bytes != TARGET_PKTS*1240 ||
                    raw_capture_packets != TARGET_PKTS ||
                    inj_capture_packets != TARGET_PKTS || inj_stall_cycles == 0) begin
                    inj_errors++;
                    $display("B.1 byte capture count bad: raw_bytes=%0d raw_pkts=%0d inj_bytes=%0d inj_pkts=%0d",
                             raw_capture_bytes, raw_capture_packets,
                             inj_capture_bytes, inj_capture_packets);
                end else begin
                    for (int p = 0; p < TARGET_PKTS; p++) begin
                        exp_nonce = 64'd1 + p;
                        for (int j = 0; j < 8; j++) begin
                            if (inj_bytes[p*1240+j] !== exp_nonce[(63-8*j) -: 8]) begin
                                inj_errors++;
                                if (inj_errors < 8)
                                    $display("B.1 byte mismatch nonce pkt=%0d byte=%0d got=%h want=%h",
                                             p, j, inj_bytes[p*1240+j], exp_nonce[(63-8*j) -: 8]);
                            end
                        end
                        for (int j = 0; j < 1232; j++) begin
                            if (inj_bytes[p*1240+8+j] !== raw_bytes[p*1232+j]) begin
                                inj_errors++;
                                if (inj_errors < 8)
                                    $display("B.1 byte mismatch CT pkt=%0d byte=%0d got=%h want=%h",
                                             p, j, inj_bytes[p*1240+8+j], raw_bytes[p*1232+j]);
                            end
                        end
                    end
                end
                $display("B.1 byte capture: raw=%0d bytes/%0d packets inj=%0d bytes/%0d packets stalls=%0d",
                         raw_capture_bytes, raw_capture_packets,
                         inj_capture_bytes, inj_capture_packets, inj_stall_cycles);
                if (ring_mem_errors != 0) begin
                    inj_errors++;
                    $display("B.2 memory model errors=%0d", ring_mem_errors);
                end
                if (ring_publish_count != TARGET_PKTS) begin
                    inj_errors++;
                    $display("B.2 publish count=%0d (want %0d)", ring_publish_count, TARGET_PKTS);
                end
                for (int slot = 0; slot < B2_RING_SLOTS; slot++) begin
                    if (ring_last_packet[slot] >= 0) begin
                        for (int b = 0; b < 1280; b++) begin
                            if (ring_mem[slot*B2_SLOT_STRIDE+b] !==
                                ((b < 1240) ? inj_bytes[ring_last_packet[slot]*1240+b] : 8'h00)) begin
                                inj_errors++;
                                if (inj_errors < 8)
                                    $display("B.2 byte mismatch slot=%0d pkt=%0d byte=%0d got=%h want=%h",
                                             slot, ring_last_packet[slot], b,
                                             ring_mem[slot*B2_SLOT_STRIDE+b],
                                             ((b < 1240) ? inj_bytes[ring_last_packet[slot]*1240+b] : 8'h00));
                            end
                        end
                    end
                end
                if (ring_axi_boundary_errors != 0) begin
                    inj_errors++;
                    $display("B.2 AXI boundary errors=%0d", ring_axi_boundary_errors);
                end
                if (ring_slot_geometry_errors != 0) begin
                    inj_errors++;
                    $display("B.2 slot geometry errors=%0d", ring_slot_geometry_errors);
                end
                if (ring_data_burst_count != TARGET_PKTS * 10) begin
                    inj_errors++;
                    $display("B.2 data burst count=%0d (want %0d)",
                             ring_data_burst_count, TARGET_PKTS * 10);
                end
                $display("B.2 ring: publishes=%0d ctrl_reads=%0d mem_errors=%0d data_bursts=%0d boundary_errors=%0d geometry_errors=%0d",
                         ring_publish_count, ring_ctrl_read_count, ring_mem_errors,
                         ring_data_burst_count, ring_axi_boundary_errors,
                         ring_slot_geometry_errors);
                if (errors == 0 && inj_errors == 0) $display("B1_B2_CHAIN_TB PASS");
                else $display("B1_B2_CHAIN_TB FAIL errors=%0d inj_errors=%0d", errors, inj_errors);
                $finish;
            end
            begin : b1_watchdog
                #10_000_000;
                $display("B1_B2_CHAIN_TB FAIL watchdog: pkt=%0d ring_pub=%0d raw_ct_valid=%0d raw_ct_ready=%0d inj_valid=%0d inj_ready=%0d pkt_valid=%0d pkt_ready=%0d cfg_enable=%0d seq_valid=%0d seq_ready=%0d seq_state=%0d key_dirty=%0d mst_wr_pending=%0d mst_rd_pending=%0d aes_stream=%0d aes_pt_ready=%0d ring_state=%0d ring_fault=%0d ring_axis_ready=%0d",
                         inj_pkt_index, ring_publish_count, ct_tvalid, ct_tready, inj_tvalid, inj_tready,
                         pkt_tvalid, pkt_tready, cfg_enable, seq_m_tvalid, seq_m_tready,
                         seq.state, seq.key_dirty, seq.mst_wr_pending, seq.mst_rd_pending,
                         aes.stream_mode_reg, aes.pt_ready,
                         ring_writer.writer_state, ring_writer.writer_fault, ring_axis_ready);
                $fatal(1);
            end
        join

    end

endmodule
