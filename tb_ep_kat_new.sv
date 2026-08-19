`timescale 1ns / 1ps
// Minimal KAT for the NEW EncryptPipelined (start_i interface).
module tb_ep_kat_new;
    reg clk = 0; reg rst = 1;
    always #5 clk = ~clk;
    reg  start_i = 0;
    reg  [0:127] in = 0;
    reg  [0:1919] expanded_key = 0;
    wire [0:127] out;
    wire valid_data;

    reg new_masterkey = 0;
    reg [0:255] masterkey = 0;
    wire [3:0] keys_ready;

    EncryptPipelined dut(
        .clk(clk), .rst(rst), .start_i(start_i), .in(in),
        .expanded_key(expanded_key), .out(out), .valid_data(valid_data)
    );

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
        in = 128'd0;
        start_i = 1; @(posedge clk); start_i = 0;
        @(posedge clk); $display("STAGE ff_1_2  = %032h", dut.ff_1_2);
        @(posedge clk); $display("STAGE ff_2_3  = %032h  ek[256:384]=%032h kr=%d", dut.ff_2_3, expanded_key[256 +:128], keys_ready);
        $display("R2 mix=%032h add=%032h", dut.round2.mix_columns_output, dut.round2.add_round_key_out);
        @(posedge clk); $display("STAGE ff_3_4  = %032h", dut.ff_3_4);
        repeat (17) @(posedge clk);
        $display("E(K,0)  = %032h  (expect f29000b62a499fd0a9f39a6add2e7780)", out);
        $display("PARAM round2.i=%0d round3.i=%0d round13.i=%0d", dut.round2.i, dut.round3.i, dut.round13.i);
        in = 128'h00112233445566778899aabbccddeeff;
        start_i = 1; @(posedge clk); start_i = 0;
        repeat (20) @(posedge clk);
        $display("E(K,x)  = %032h  (expect 8ea2b7ca516745bfeafc49904b496089)", out);
        $finish;
    end
endmodule
