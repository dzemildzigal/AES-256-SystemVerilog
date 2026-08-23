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
        .dbg_push_data(dbg_push), .dbg_maxis_last_beat(dbg_maxis)
    );

    assign ct_tready = 1'b1;

    // ---- AXI-Lite master tasks (the sequencer's config port) ----
    task axi_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_axi_awaddr <= addr; s_axi_awvalid <= 1'b1;
            $display("T%0t WR %h: awvalid=1 awready=%0d", $time, addr, s_axi_awready);
            wait (s_axi_awready);
            $display("T%0t WR %h: aw done, wvalid=1 wready=%0d", $time, addr, s_axi_wready);
            s_axi_wdata <= data; s_axi_wvalid <= 1'b1;
            s_axi_awvalid <= 1'b0;
            wait (s_axi_wready);
            $display("T%0t WR %h: w done, bvalid=%0d", $time, addr, s_axi_bvalid);
            s_axi_wvalid <= 1'b0;
            wait (s_axi_bvalid);
            s_axi_bready <= 1'b1;
            @(posedge clk);
            s_axi_bready <= 1'b0;
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

    // debug: watch the slave handshakes
    always @(posedge clk) begin
        if (s_axi_awvalid || s_axi_wvalid || s_axi_awready || s_axi_wready)
            $display("T%0t SLAVE awv=%0d awr=%0d wv=%0d wr=%0d bv=%0d",
                     $time, s_axi_awvalid, s_axi_awready, s_axi_wvalid, s_axi_wready, s_axi_bvalid);
    end

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

    // ---- the config + the run ----
    integer i;
    reg [31:0] key_words [0:7];
    initial begin
        key_words[0]=32'h00010203; key_words[1]=32'h04050607;
        key_words[2]=32'h08090a0b; key_words[3]=32'h0c0d0e0f;
        key_words[4]=32'h10111213; key_words[5]=32'h14151617;
        key_words[6]=32'h18191a1b; key_words[7]=32'h1c1d1e1f;

        rstn = 0;
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

        // run until the feeder finishes + the pipeline drains
        wait (feed_active == 1'b1);
        wait (feed_active == 1'b0);
        #5000;

        $display("DONE beats=%0d tlasts=%0d (expect %0d) errors=%0d first_stall=%0d",
                 beats_total, tlast_total, 2 * SEGS, errors, first_stall);
        if (tlast_total != 2 * SEGS) errors++;
        if (errors == 0) $display("FULLCHAIN_TB PASS");
        else             $display("FULLCHAIN_TB FAIL errors=%0d", errors);
        $finish;
    end

endmodule
