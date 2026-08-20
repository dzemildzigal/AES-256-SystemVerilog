`timescale 1ns / 1ps
// Multi-packet wrapper KAT: stream 3 packets back-to-back (no pacer), each
// 76 PT beats + tlast, and compare every wire tag against the software tags
// computed offline. Reproduces the intermittent tag-beat misalignment seen
// on the board: wire tag = {tag[0:96], ghash[0:32]}.
module tb_wrapper_multi;
    reg clk = 0; reg rstn = 0;
    always #5 clk = ~clk;

    reg  [7:0]  awaddr = 0; reg awvalid = 0; wire awready;
    reg  [31:0] wdata = 0;  reg wvalid = 0;  wire wready;
    wire [1:0]  bresp;      wire bvalid;     reg bready = 1;
    reg  [7:0]  araddr = 0; reg arvalid = 0; wire arready;
    wire [31:0] rdata;      wire [1:0] rresp; wire rvalid; reg rready = 1;

    reg  [127:0] pt_tdata = 0; reg [15:0] pt_tkeep = 16'hFFFF;
    reg  pt_tlast = 0; reg pt_tvalid = 0; wire pt_tready;
    wire [127:0] ct_tdata; wire [15:0] ct_tkeep;
    wire ct_tlast; wire ct_tvalid; reg ct_tready = 1;

    AXI_AES_GCM_Stream dut(
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rstn),
        .S_AXI_AWADDR(awaddr), .S_AXI_AWPROT(3'b0), .S_AXI_AWVALID(awvalid), .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata), .S_AXI_WSTRB(4'hF), .S_AXI_WVALID(wvalid), .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp), .S_AXI_BVALID(bvalid), .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr), .S_AXI_ARPROT(3'b0), .S_AXI_ARVALID(arvalid), .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata), .S_AXI_RRESP(rresp), .S_AXI_RVALID(rvalid), .S_AXI_RREADY(rready),
        .S_AXIS_PT_TDATA(pt_tdata), .S_AXIS_PT_TKEEP(pt_tkeep),
        .S_AXIS_PT_TLAST(pt_tlast), .S_AXIS_PT_TVALID(pt_tvalid), .S_AXIS_PT_TREADY(pt_tready),
        .M_AXIS_CT_TDATA(ct_tdata), .M_AXIS_CT_TKEEP(ct_tkeep),
        .M_AXIS_CT_TLAST(ct_tlast), .M_AXIS_CT_TVALID(ct_tvalid), .M_AXIS_CT_TREADY(ct_tready)
    );

    task axi_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr <= addr; awvalid <= 1; wdata <= data; wvalid <= 1;
            wait (awready && wready);
            @(posedge clk);
            awvalid <= 0; wvalid <= 0;
        end
    endtask

    integer beat = 0;
    // capture every CT beat with the tag mask mirror value at that moment
    always @(posedge clk) begin
        if (ct_tvalid && ct_tready) begin
            $display("BEAT %0d %032h last=%0d", beat, ct_tdata, ct_tlast);
            beat = beat + 1;
        end
    end

    // probe the engine's tag mask + tag_out vs the pushed beat at tag time
    always @(posedge clk) begin
        if (dut.gm.tag_valid_o)
            $display("TAG_EVENT t=%0t tag_out=%032h", $time, dut.gm.tag_out_o);
        if (dut.push_tag_now)
            $display("TAG_PUSH  t=%0t push_data=%032h tag_latched=%032h ghash_latched=%032h",
                     $time, dut.push_data, dut.tag_latched, dut.ghash_latched);
    end

    integer i, pkt;
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

        for (i = 0; i < 8; i = i + 1) axi_write(8'h08 + i*4, key_words[i]);
        axi_write(8'h00, 32'h2);          // load_key
        repeat (40) @(posedge clk);
        axi_write(8'h00, 32'h80);         // set stream mode

        // stream 3 packets back-to-back: nonce counter = pkt+1
        for (pkt = 0; pkt < 3; pkt = pkt + 1) begin
            axi_write(8'h28, 32'h00000001);
            axi_write(8'h2C, 32'h00000000);
            axi_write(8'h30, 32'h00000001 + pkt);
            axi_write(8'h34, 32'h0);
            axi_write(8'h38, 32'h0);
            axi_write(8'h3C, 32'h0);
            axi_write(8'h40, 32'd9728);
            axi_write(8'h00, 32'h4);      // start session
            for (i = 0; i < 76; i = i + 1) begin
                pt_tdata  <= {16{i[7:0]}} + pkt; // vary per packet
                pt_tlast  <= (i == 75);
                pt_tvalid <= 1;
                @(posedge clk);
                while (!pt_tready) @(posedge clk);
            end
            pt_tvalid <= 0; pt_tlast <= 0;
        end

        repeat (80) @(posedge clk);
        $display("DONE beats=%0d", beat);
        $finish;
    end
endmodule
