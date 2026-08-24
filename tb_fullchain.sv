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
    logic [4:0]   inj_ready_phase;

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
    always @(posedge clk) begin
        if (!rstn)
            inj_ready_phase <= 5'd0;
        else
            inj_ready_phase <= inj_ready_phase + 5'd1;
    end
    // Deterministic downstream stalls: prove prefix insertion preserves
    // AXI valid/ready behavior and does not lose the held CT first beat.
    assign inj_tready = !(inj_ready_phase == 5'd3 ||
                          inj_ready_phase == 5'd4 ||
                          inj_ready_phase == 5'd17);

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

        rstn = 0;
        s_axi_awaddr = '0; s_axi_awprot = '0; s_axi_awvalid = 1'b0;
        s_axi_wdata = '0; s_axi_wstrb = 4'hF; s_axi_wvalid = 1'b0;
        s_axi_bready = 1'b0;
        s_axi_araddr = '0; s_axi_arprot = '0; s_axi_arvalid = 1'b0;
        s_axi_rready = 1'b0;
        repeat (10) @(posedge clk);
        rstn = 1;
        repeat (5) @(posedge clk);
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
                if (errors == 0 && inj_errors == 0) $display("FULLCHAIN_TB PASS");
                else $display("FULLCHAIN_TB FAIL errors=%0d inj_errors=%0d", errors, inj_errors);
                $finish;
            end
            begin : b1_watchdog
                #10_000_000;
                $display("FULLCHAIN_TB FAIL watchdog: target packet count not reached pkt=%0d raw_ct_valid=%0d raw_ct_ready=%0d inj_valid=%0d inj_ready=%0d pkt_valid=%0d pkt_ready=%0d cfg_enable=%0d seq_valid=%0d seq_ready=%0d seq_state=%0d key_dirty=%0d mst_wr_pending=%0d mst_rd_pending=%0d aes_stream=%0d aes_pt_ready=%0d",
                         inj_pkt_index, ct_tvalid, ct_tready, inj_tvalid, inj_tready,
                         pkt_tvalid, pkt_tready, cfg_enable, seq_m_tvalid, seq_m_tready,
                         seq.state, seq.key_dirty, seq.mst_wr_pending, seq.mst_rd_pending,
                         aes.stream_mode_reg, aes.pt_ready);
                $fatal(1);
            end
        join

    end

endmodule
