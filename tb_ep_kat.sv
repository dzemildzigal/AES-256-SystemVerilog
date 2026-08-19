`timescale 1ns / 1ps
// Minimal KAT for EncryptPipelined (old interface, no start_i).
module tb_ep_kat;
    reg clk = 0; reg rst = 1;
    always #5 clk = ~clk;
    reg  [0:127] in = 0;
    reg  [0:1919] expanded_key = 0;
    wire [0:127] out;
    wire valid_data;

    EncryptPipelined dut(
        .clk(clk), .rst(rst), .in(in), .expanded_key(expanded_key),
        .out(out), .valid_data(valid_data),
        .ff_1_2_o(), .ff_2_3_o(), .ff_3_4_o(), .ff_4_5_o(), .ff_5_6_o(),
        .ff_6_7_o(), .ff_7_8_o(), .ff_8_9_o(), .ff_9_10_o(), .ff_10_11_o(),
        .ff_11_12_o(), .ff_12_13_o(), .ff_13_14_o()
    );

    reg new_masterkey = 0;
    reg [0:255] masterkey = 0;
    wire [3:0] keys_ready;

    KeyExpansion ke(
        .clk(clk), .rst(rst), .new_masterkey(new_masterkey),
        .masterkey(masterkey), .w(expanded_key), .keys_ready(keys_ready)
    );

    initial begin
        masterkey = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
        repeat (5) @(posedge clk);
        rst = 0;
        @(posedge clk);
        new_masterkey = 1; @(posedge clk); new_masterkey = 0;
        wait (keys_ready == 4'd15);
        repeat (5) @(posedge clk);
        // E(K, 0) must be f29000b62a499fd0a9f39a6add2e7780
        in = 128'd0;
        repeat (20) @(posedge clk);
        $display("E(K,0)  = %032h  (expect f29000b62a499fd0a9f39a6add2e7780)", out);
        // E(K, 00112233445566778899aabbccddeeff) = 8ea2b7ca516745bfeafc49904b496089
        in = 128'h00112233445566778899aabbccddeeff;
        repeat (20) @(posedge clk);
        $display("E(K,x)  = %032h  (expect 8ea2b7ca516745bfeafc49904b496089)", out);
        $finish;
    end
endmodule
