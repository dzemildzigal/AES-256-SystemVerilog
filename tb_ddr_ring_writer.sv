`timescale 1ns / 1ps

module tb_ddr_ring_writer;
    localparam integer PACKET_BYTES = 1240;
    localparam integer SLOT_BYTES = 1280;
    localparam integer PACKET_WORDS = 155;  // 1240 bytes / 8-byte AXI words
    localparam integer SLOT_WORDS = 160;    // 1280 bytes / 8-byte AXI words
    localparam integer AXIS_BEATS = 78;     // 1 prefix beat + 77 CT/tag beats
    localparam integer RING_LOG2 = 11;
    localparam integer RING_SLOTS = 1 << RING_LOG2;
    localparam integer SLOT_STRIDE = 1280;
    localparam [31:0] RING_BASE = 32'h1000_0000;
    localparam [31:0] CTRL_BASE = 32'h2000_0000;
    localparam integer DRAIN_PACKETS = 10000;
    localparam integer DROP_PACKETS = RING_SLOTS + 16;

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rstn = 1'b0;

    logic [7:0]  sa_awaddr;
    logic [2:0]  sa_awprot = 0;
    logic        sa_awvalid = 0, sa_awready;
    logic [31:0] sa_wdata;
    logic [3:0]  sa_wstrb = 4'hF;
    logic        sa_wvalid = 0, sa_wready;
    logic [1:0]  sa_bresp;
    logic        sa_bvalid, sa_bready = 0;
    logic [7:0]  sa_araddr;
    logic [2:0]  sa_arprot = 0;
    logic        sa_arvalid = 0, sa_arready;
    logic [31:0] sa_rdata;
    logic [1:0]  sa_rresp;
    logic        sa_rvalid, sa_rready = 0;

    logic [31:0] ma_awaddr;
    logic [7:0]  ma_awlen;
    logic [2:0]  ma_awsize;
    logic [1:0]  ma_awburst;
    logic        ma_awvalid, ma_awready = 1'b1;
    logic [63:0] ma_wdata;
    logic [7:0]  ma_wstrb;
    logic        ma_wlast;
    logic        ma_wvalid, ma_wready = 1'b1;
    logic [1:0]  ma_bresp = 2'b00;
    logic        ma_bvalid = 1'b0, ma_bready;
    logic [31:0] ma_araddr;
    logic [2:0]  ma_arprot;
    logic        ma_arvalid, ma_arready = 1'b1;
    logic [31:0] ma_rdata;
    logic [1:0]  ma_rresp = 2'b00;
    logic        ma_rvalid = 1'b0, ma_rready;

    logic [127:0] axis_tdata;
    logic [15:0]  axis_tkeep;
    logic         axis_tlast, axis_tvalid, axis_tready;
    logic         irq;

    DDRRingWriter #(
        .PACKET_BYTES(PACKET_BYTES), .SLOT_STRIDE(SLOT_STRIDE),
        .RING_LOG2(RING_LOG2)
    ) dut (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rstn),
        .S_AXI_AWADDR(sa_awaddr), .S_AXI_AWPROT(sa_awprot),
        .S_AXI_AWVALID(sa_awvalid), .S_AXI_AWREADY(sa_awready),
        .S_AXI_WDATA(sa_wdata), .S_AXI_WSTRB(sa_wstrb),
        .S_AXI_WVALID(sa_wvalid), .S_AXI_WREADY(sa_wready),
        .S_AXI_BRESP(sa_bresp), .S_AXI_BVALID(sa_bvalid),
        .S_AXI_BREADY(sa_bready), .S_AXI_ARADDR(sa_araddr),
        .S_AXI_ARPROT(sa_arprot), .S_AXI_ARVALID(sa_arvalid),
        .S_AXI_ARREADY(sa_arready), .S_AXI_RDATA(sa_rdata),
        .S_AXI_RRESP(sa_rresp), .S_AXI_RVALID(sa_rvalid),
        .S_AXI_RREADY(sa_rready),
        .M_AXI_AWADDR(ma_awaddr), .M_AXI_AWLEN(ma_awlen),
        .M_AXI_AWSIZE(ma_awsize), .M_AXI_AWBURST(ma_awburst),
        .M_AXI_AWVALID(ma_awvalid), .M_AXI_AWREADY(ma_awready),
        .M_AXI_WDATA(ma_wdata), .M_AXI_WSTRB(ma_wstrb),
        .M_AXI_WLAST(ma_wlast), .M_AXI_WVALID(ma_wvalid),
        .M_AXI_WREADY(ma_wready), .M_AXI_BRESP(ma_bresp),
        .M_AXI_BVALID(ma_bvalid), .M_AXI_BREADY(ma_bready),
        .M_AXI_ARADDR(ma_araddr), .M_AXI_ARPROT(ma_arprot),
        .M_AXI_ARVALID(ma_arvalid), .M_AXI_ARREADY(ma_arready),
        .M_AXI_RDATA(ma_rdata), .M_AXI_RRESP(ma_rresp),
        .M_AXI_RVALID(ma_rvalid), .M_AXI_RREADY(ma_rready),
        .S_AXIS_TDATA(axis_tdata), .S_AXIS_TKEEP(axis_tkeep),
        .S_AXIS_TLAST(axis_tlast), .S_AXIS_TVALID(axis_tvalid),
        .S_AXIS_TREADY(axis_tready), .irq(irq)
    );

    // Sparse enough for this test: 2048 x 1280 = 2.5 MiB.
    logic [7:0] mem [0:RING_SLOTS*SLOT_STRIDE-1];
    logic [31:0] ctrl_consume = 0;
    logic [31:0] ctrl_produce = 0;
    logic consume_enabled = 1'b1;
    logic ma_aw_seen = 1'b0;
    logic [31:0] ma_write_addr;
    integer ma_write_beats_left;
    integer mem_write_errors = 0;
    integer axi_boundary_errors = 0;
    integer slot_boundary_errors = 0;
    integer data_burst_count = 0;
    integer ctrl_read_count = 0;
    integer ctrl_publish_count = 0;

    // AXI master write/read memory model. One-cycle B/R responses.
    always @(posedge clk) begin
        if (!rstn) begin
            ma_bvalid <= 1'b0;
            ma_rvalid <= 1'b0;
            ma_aw_seen <= 1'b0;
            ma_write_beats_left <= 0;
        end else begin
            if (ma_awvalid && ma_awready) begin
                integer burst_bytes;
                integer slot_offset;
                burst_bytes = (ma_awlen + 1) * 8;
                if (ma_awaddr >= RING_BASE &&
                    ma_awaddr < RING_BASE + RING_SLOTS*SLOT_STRIDE) begin
                    slot_offset = (ma_awaddr - RING_BASE) % SLOT_STRIDE;
                    if (((ma_awaddr & 32'h00000FFF) + burst_bytes) > 4096)
                        axi_boundary_errors = axi_boundary_errors + 1;
                    if ((slot_offset + burst_bytes) > SLOT_STRIDE)
                        slot_boundary_errors = slot_boundary_errors + 1;
                    if (ma_awlen != 8'd15)
                        slot_boundary_errors = slot_boundary_errors + 1;
                    data_burst_count = data_burst_count + 1;
                end
                ma_aw_seen <= 1'b1;
                ma_write_addr <= ma_awaddr;
                ma_write_beats_left <= ma_awlen + 1;
            end
            if (ma_wvalid && ma_wready) begin
                if (!ma_aw_seen || ma_write_beats_left <= 0) begin
                    mem_write_errors = mem_write_errors + 1;
                end else if (ma_write_addr >= RING_BASE &&
                             ma_write_addr < RING_BASE + RING_SLOTS*SLOT_STRIDE) begin
                    for (integer b = 0; b < 8; b = b + 1)
                        if (ma_wstrb[b])
                            mem[ma_write_addr - RING_BASE + b] = ma_wdata[8*b +: 8];
                end else if (ma_write_addr == CTRL_BASE) begin
                    ctrl_produce = ma_wdata[31:0];
                    ctrl_publish_count = ctrl_publish_count + 1;
                    if (consume_enabled)
                        ctrl_consume = ctrl_produce;
                end else begin
                    mem_write_errors = mem_write_errors + 1;
                end
                ma_write_addr <= ma_write_addr + 8;
                ma_write_beats_left <= ma_write_beats_left - 1;
                if (ma_wlast) begin
                    ma_aw_seen <= 1'b0;
                    ma_bvalid <= 1'b1;
                end
            end
            if (ma_bvalid && ma_bready)
                ma_bvalid <= 1'b0;

            if (ma_arvalid && ma_arready) begin
                if (ma_araddr == CTRL_BASE + 4) begin
                    ma_rdata <= ctrl_consume;
                    ctrl_read_count = ctrl_read_count + 1;
                end else begin
                    ma_rdata <= 32'hDEAD_BEEF;
                end
                ma_rvalid <= 1'b1;
            end
            if (ma_rvalid && ma_rready)
                ma_rvalid <= 1'b0;
        end
    end

    // AXI-Lite configuration driver.
    task automatic axi_write(input [7:0] addr, input [31:0] data);
        begin
            // Hold both VALID signals from a falling edge through the actual
            // rising-edge handshake. The DUT accepts AW and W together.
            @(negedge clk);
            sa_awaddr  = addr;
            sa_wdata   = data;
            sa_awvalid = 1'b1;
            sa_wvalid  = 1'b1;
            while (!(sa_awready && sa_wready))
                @(posedge clk);
            @(negedge clk);
            sa_awvalid = 1'b0;
            sa_wvalid  = 1'b0;
            sa_bready  = 1'b1;
            while (!sa_bvalid)
                @(posedge clk);
            @(posedge clk);
            @(negedge clk);
            sa_bready = 1'b0;
        end
    endtask

    task automatic configure;
        begin
            axi_write(8'h0C, RING_BASE);
            axi_write(8'h10, 0);
            axi_write(8'h14, CTRL_BASE);
            axi_write(8'h18, 0);
            axi_write(8'h04, 32'h1); // control enable
        end
    endtask

    // Packet source. Byte k of packet p is p+k, except the first 8 bytes are
    // the B.1 nonce prefix p in big-endian form.
    integer src_packet = 0;
    integer src_beat = 0;
    logic src_running = 1'b0;
    integer source_target;
    integer source_sent = 0;
    logic drop_phase = 1'b0;
    integer verify_count = 0;
    integer verify_errors = 0;
    integer expected_last_packet [0:RING_SLOTS-1];
    integer drop_start_complete;
    integer drop_start_drop;
    logic record_expected = 1'b0;

    function automatic [7:0] packet_byte(input integer p, input integer byte_i);
        begin
            if (byte_i < 8)
                packet_byte = (p >> (8*(7-byte_i))) & 8'hFF;
            else if (byte_i < PACKET_BYTES)
                packet_byte = (p + byte_i) & 8'hFF;
            else
                packet_byte = 8'h00;
        end
    endfunction

    always @* begin
        axis_tvalid = src_running;
        axis_tkeep = (src_beat == 0) ? 16'h00FF : 16'hFFFF;
        axis_tlast = (src_beat == AXIS_BEATS-1);
        axis_tdata = 0;
        if (src_beat == 0) begin
            for (integer b = 0; b < 8; b = b + 1)
                axis_tdata[8*b +: 8] = packet_byte(src_packet, b);
        end else begin
            for (integer b = 0; b < 16; b = b + 1)
                axis_tdata[8*b +: 8] = packet_byte(src_packet, 8 +
                    (src_beat-1)*16 + b);
        end
    end

    always @(posedge clk) begin
        if (!rstn) begin
            src_packet <= 0;
            src_beat <= 0;
            src_running <= 1'b0;
        end else if (src_running && axis_tvalid && axis_tready) begin
            if (axis_tlast) begin
                if (record_expected)
                    expected_last_packet[src_packet & (RING_SLOTS-1)] = src_packet;
                source_sent = source_sent + 1;
                if (source_sent >= source_target) begin
                    src_running <= 1'b0;
                end else begin
                    src_packet <= src_packet + 1;
                    src_beat <= 0;
                end
            end else begin
                src_beat <= src_beat + 1;
            end
        end
    end

    // Byte verification is performed after the drain phase. This avoids
    // simulator scheduling races between the memory model's control write
    // and the writer's publication signal. expected_last_packet records the
    // last packet that belongs in each slot.
    task automatic verify_slots;
        begin
            verify_count = 0;
            verify_errors = 0;
            for (integer slot = 0; slot < RING_SLOTS; slot = slot + 1) begin
                if (expected_last_packet[slot] >= 0) begin
                    for (integer b = 0; b < SLOT_BYTES; b = b + 1) begin
                        if (mem[slot*SLOT_STRIDE+b] !==
                            packet_byte(expected_last_packet[slot], b))
                            verify_errors = verify_errors + 1;
                    end
                    verify_count = verify_count + 1;
                end
            end
        end
    endtask

    task automatic run_source(input integer count);
        begin
            source_target = count;
            src_packet = 0;
            src_beat = 0;
            source_sent = 0;
            src_running = 1'b1;
            while (src_running) @(posedge clk);
            @(posedge clk);
        end
    endtask

    initial begin
        for (integer i = 0; i < RING_SLOTS; i = i + 1)
            expected_last_packet[i] = -1;
        rstn = 1'b0;
        repeat (10) @(posedge clk);
        rstn = 1'b1;
        configure();
        record_expected = 1'b1;

        // Drain mode: 10,000 packets, every slot consumed at publication.
        run_source(DRAIN_PACKETS);
        while (dut.complete_count < DRAIN_PACKETS)
            @(posedge clk);
        repeat (100) @(posedge clk);
        if (source_sent != DRAIN_PACKETS) begin
            $display("source count bad: source_sent=%0d target=%0d produce=%0d complete=%0d drops=%0d fault=%0d",
                     source_sent, DRAIN_PACKETS, dut.produce_idx,
                     dut.complete_count, dut.drop_count, dut.writer_fault);
            $fatal(1, "source count bad");
        end
        if (ctrl_publish_count != DRAIN_PACKETS) $fatal(1, "publish count %0d", ctrl_publish_count);
        if (mem_write_errors != 0) $fatal(1, "memory model errors %0d", mem_write_errors);
        if (axi_boundary_errors != 0)
            $fatal(1, "AXI 4KiB boundary errors %0d", axi_boundary_errors);
        if (slot_boundary_errors != 0)
            $fatal(1, "slot/burst geometry errors %0d", slot_boundary_errors);
        if (data_burst_count != DRAIN_PACKETS * 10)
            $fatal(1, "data burst count %0d (want %0d)", data_burst_count, DRAIN_PACKETS * 10);
        verify_slots();
        if (verify_errors != 0)
            $fatal(1, "slot data errors after drain: %0d", verify_errors);
        record_expected = 1'b0;

        // Forced-full mode: consume index is frozen. The ring must drop whole
        // packets after its N-1 usable slots; no AXI write may be partial.
        consume_enabled = 1'b0;
        drop_start_complete = ctrl_publish_count;
        drop_start_drop = dut.drop_count;
        run_source(DROP_PACKETS);
        repeat (100) @(posedge clk);
        if (dut.drop_count <= drop_start_drop)
            $fatal(1, "full ring did not count drops");
        if (dut.complete_count <= drop_start_complete)
            $fatal(1, "full ring did not publish initial slots");
        if (mem_write_errors != 0) $fatal(1, "memory model errors after drop");
        if (axi_boundary_errors != 0)
            $fatal(1, "AXI boundary errors after drop %0d", axi_boundary_errors);
        if (slot_boundary_errors != 0)
            $fatal(1, "slot geometry errors after drop %0d", slot_boundary_errors);
        if (dut.writer_fault) $fatal(1, "writer fault code %0d", dut.fault_code);

        $display("B2_RING_TB PASS drain=%0d publishes=%0d verify=%0d verify_errors=%0d drops=%0d ctrl_reads=%0d data_bursts=%0d",
                 source_sent, ctrl_publish_count, verify_count, verify_errors,
                 dut.drop_count, ctrl_read_count, data_burst_count);
        if (verify_errors != 0) $fatal(1, "slot data/padding errors %0d", verify_errors);
        $display("B2 geometry: data_bursts=%0d expected=%0d boundary_errors=%0d slot_errors=%0d",
                 data_burst_count, DRAIN_PACKETS * 10,
                 axi_boundary_errors, slot_boundary_errors);
        $finish;
    end

    initial begin
        #200_000_000;
        $display("B2 watchdog state=%0d source_sent=%0d src_running=%0d produce=%0d consume=%0d complete=%0d drops=%0d fault=%0d fault_code=%0d cap_words=%0d slot=%0d axis_valid=%0d axis_ready=%0d awvalid=%0d wvalid=%0d bready=%0d arvalid=%0d rvalid=%0d aw_seen=%0d beats_left=%0d",
                 dut.writer_state, source_sent, src_running,
                 dut.produce_idx, ctrl_consume, dut.complete_count,
                 dut.drop_count, dut.writer_fault, dut.fault_code,
                 dut.capture_word_count, dut.target_slot,
                 axis_tvalid, axis_tready, ma_awvalid, ma_wvalid,
                 ma_bready, ma_arvalid, ma_rvalid,
                 ma_aw_seen, ma_write_beats_left);
        $fatal(1, "B2_RING_TB watchdog");
    end
endmodule
