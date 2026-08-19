`timescale 1ns / 1ps
// Wrapper-level KAT: drive AXI_AES_GCM_Stream like the sequencer does,
// stream 76 known PT beats, print every M_AXIS_CT beat for Python checking.
module tb_wrapper_stream;
    reg clk = 0; reg rstn = 0;
    always #5 clk = ~clk;

    // AXI-Lite
    reg  [7:0]  awaddr = 0; reg awvalid = 0; wire awready;
    reg  [31:0] wdata = 0;  reg wvalid = 0;  wire wready;
    wire [1:0]  bresp;      wire bvalid;     reg bready = 1;
    reg  [7:0]  araddr = 0; reg arvalid = 0; wire arready;
    wire [31:0] rdata;      wire [1:0] rresp; wire rvalid; reg rready = 1;

    // PT stream in
    reg  [127:0] pt_tdata = 0; reg [15:0] pt_tkeep = 16'hFFFF;
    reg  pt_tlast = 0; reg pt_tvalid = 0; wire pt_tready;
    // CT stream out
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
    // capture every CT beat
    always @(posedge clk) begin
        if (ct_tvalid && ct_tready) begin
            $display("BEAT %0d %032h", beat, ct_tdata);
            beat = beat + 1;
        end
    end

    // probe the shared encrypt pipeline: launches and outputs
    always @(posedge clk) begin
        if (dut.gm.enc_start)
            $display("LAUNCH t=%0t src=%0d in=%032h", $time, dut.gm.enc_src, dut.gm.enc_in);
        if (dut.gm.enc_valid)
            $display("ENOUT  t=%0t srcpipe14=%0d out=%032h", $time, dut.gm.src_pipe[14], dut.gm.enc_out);
    end

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

        // key
        for (i = 0; i < 8; i = i + 1) axi_write(8'h08 + i*4, key_words[i]);
        axi_write(8'h00, 32'h2);          // load_key
        repeat (40) @(posedge clk);       // wait key schedule

        axi_write(8'h00, 32'h80);         // set stream mode

        // nonce: domain=1, counter=1
        axi_write(8'h28, 32'h00000001);
        axi_write(8'h2C, 32'h00000000);
        axi_write(8'h30, 32'h00000001);
        // aad len = 0, pt len = 9728 bits
        axi_write(8'h34, 32'h0);
        axi_write(8'h38, 32'h0);
        axi_write(8'h3C, 32'h0);
        axi_write(8'h40, 32'd9728);
        // start session
        axi_write(8'h00, 32'h4);

        // stream 76 PT beats: block i = byte value i repeated 16x
        // (start streaming ~3 cycles after session start, like the sequencer)
        repeat (3) @(posedge clk);
        for (i = 0; i < 76; i = i + 1) begin
            pt_tdata  <= {16{i[7:0]}};
            pt_tlast  <= (i == 75);
            pt_tvalid <= 1;
            @(posedge clk);
            while (!pt_tready) @(posedge clk);
        end
        pt_tvalid <= 0; pt_tlast <= 0;

        // let the tag come out
        repeat (60) @(posedge clk);
        $display("PROBE key_reg      = %064h", dut.key_reg);
        $display("PROBE exp_key[0:128]= %032h", dut.gm.expanded_key[0:127]);
        $display("PROBE exp_key_full  = %0480h", dut.gm.expanded_key);
        $display("PROBE nonce_reg    = %024h", dut.gm.nonce_reg);
        $display("PROBE h_reg        = %032h", dut.gm.h_reg);
        $display("PROBE tag_mask_reg = %032h", dut.gm.tag_mask_reg);
        $display("PROBE pt_len       = %016h", dut.gm.pt_len_bits_reg);
        $display("PROBE aad_len      = %016h", dut.gm.aad_len_bits_reg);
        $display("DONE beats=%0d", beat);
        $finish;
    end
endmodule
