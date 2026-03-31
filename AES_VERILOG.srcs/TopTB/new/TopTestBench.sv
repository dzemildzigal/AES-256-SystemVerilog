`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Top-level testbench: KeyExpansion + EncryptPipelined end-to-end.
// Demonstrates: key load → wait for expansion → encrypt → verify ciphertext.

module TopTestBench;
    reg clk;
    reg rst;
    reg new_masterkey;
    reg [0:255] masterkey;
    wire [3:0] keys_ready;
    reg start_i;
    reg [0:127] plaintext;
    wire [0:127] ciphertext;
    wire ct_valid;

    Top top(
        .clk(clk),
        .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .keys_ready(keys_ready),
        .start_i(start_i),
        .plaintext(plaintext),
        .ciphertext(ciphertext),
        .ct_valid(ct_valid)
    );

    integer errors;

    initial begin
        $display("[Top TB] Starting...");
        errors = 0;
        clk = 0;
        rst = 0;
        new_masterkey = 0;
        masterkey = '0;
        start_i = 0;
        plaintext = '0;

        // ---- Reset ----
        @(posedge clk);
        rst = 1;
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ================================================================
        // Test 1: All-zero key, all-zero plaintext
        //   Expected ciphertext: dc95c078a2408989ad48a21492842087
        // ================================================================
        $display("  T1: zero key, zero plaintext");
        masterkey = 256'h0000000000000000000000000000000000000000000000000000000000000000;
        new_masterkey = 1;
        @(posedge clk);
        #1; new_masterkey = 0;

        // Wait for all 15 round keys to be ready
        wait(keys_ready == 4'd15);
        @(posedge clk);

        plaintext = 128'h00000000000000000000000000000000;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        plaintext = '0;

        // Wait for result (15 cycles pipeline latency)
        repeat(14) @(posedge clk);
        #1;
        if (ct_valid !== 1'b1) begin $display("FAIL T1: ct_valid not asserted"); errors = errors + 1; end
        if (ciphertext !== 128'hdc95c078a2408989ad48a21492842087) begin $display("FAIL T1: wrong ct, got %h", ciphertext); errors = errors + 1; end

        @(posedge clk);
        #1;
        if (ct_valid !== 1'b0) begin $display("FAIL T1: ct_valid should deassert"); errors = errors + 1; end

        // ================================================================
        // Test 2: NIST AES-256 key (000102...1f), plaintext 00112233..eeff
        //   Expected ciphertext: 8ea2b7ca516745bfeafc49904b496089
        // ================================================================
        $display("  T2: NIST key, NIST plaintext");
        masterkey = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
        new_masterkey = 1;
        @(posedge clk);
        #1; new_masterkey = 0;

        wait(keys_ready == 4'd15);
        @(posedge clk);

        plaintext = 128'h00112233445566778899aabbccddeeff;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        plaintext = '0;

        repeat(14) @(posedge clk);
        #1;
        if (ct_valid !== 1'b1) begin $display("FAIL T2: ct_valid not asserted"); errors = errors + 1; end
        if (ciphertext !== 128'h8ea2b7ca516745bfeafc49904b496089) begin $display("FAIL T2: wrong ct, got %h", ciphertext); errors = errors + 1; end

        // ================================================================
        // Test 3: NIST key, zero plaintext
        //   Expected ciphertext: f29000b62a499fd0a9f39a6add2e7780
        // ================================================================
        $display("  T3: NIST key, zero plaintext (same key, no re-expand)");
        // Key is already expanded, reuse it
        plaintext = 128'h00000000000000000000000000000000;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        plaintext = '0;

        repeat(14) @(posedge clk);
        #1;
        if (ct_valid !== 1'b1) begin $display("FAIL T3: ct_valid not asserted"); errors = errors + 1; end
        if (ciphertext !== 128'hf29000b62a499fd0a9f39a6add2e7780) begin $display("FAIL T3: wrong ct, got %h", ciphertext); errors = errors + 1; end

        // ================================================================
        // Test 4: Custom key, "Hello world!  :)"
        //   Key: "ThisIsTheBesTPassword_ICan_ThinkOf"  (first 32 bytes)
        //   Expected ciphertext: 8e00ecc38998b9806a9559f59054aaa6
        // ================================================================
        $display("  T4: custom key, Hello world");
        masterkey = 256'h5468697349735468654265737450617373776f72644943616e5468696e6b4f66;
        new_masterkey = 1;
        @(posedge clk);
        #1; new_masterkey = 0;

        wait(keys_ready == 4'd15);
        @(posedge clk);

        plaintext = "Hello world!  :)";
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        plaintext = '0;

        repeat(14) @(posedge clk);
        #1;
        if (ct_valid !== 1'b1) begin $display("FAIL T4: ct_valid not asserted"); errors = errors + 1; end
        if (ciphertext !== 128'hea1044c3b1139b6cf71095be1071b90d) begin $display("FAIL T4: wrong ct, got %h", ciphertext); errors = errors + 1; end

        // ================================================================
        // Test 5: Streaming — 3 blocks back-to-back, NIST key
        //   Verifies pipeline throughput after fill
        // ================================================================
        $display("  T5: 3-block stream, NIST key");
        masterkey = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
        new_masterkey = 1;
        @(posedge clk);
        #1; new_masterkey = 0;

        wait(keys_ready == 4'd15);
        @(posedge clk);

        start_i = 1;
        plaintext = 128'h00000000000000000000000000000000;
        @(posedge clk);
        plaintext = 128'h00112233445566778899aabbccddeeff;
        @(posedge clk);
        plaintext = 128'h00000000000000000000000000000000;
        @(posedge clk);
        #1; start_i = 0;
        plaintext = '0;

        // Wait for first result: 3 feeds already done, need 11 more posedges + check
        repeat(11) @(posedge clk);
        @(posedge clk);
        #1;
        if (ct_valid !== 1'b1) begin $display("FAIL T5a: ct_valid not asserted"); errors = errors + 1; end
        if (ciphertext !== 128'hf29000b62a499fd0a9f39a6add2e7780) begin $display("FAIL T5a: wrong ct, got %h", ciphertext); errors = errors + 1; end
        @(posedge clk);
        #1;
        if (ct_valid !== 1'b1) begin $display("FAIL T5b: ct_valid not asserted"); errors = errors + 1; end
        if (ciphertext !== 128'h8ea2b7ca516745bfeafc49904b496089) begin $display("FAIL T5b: wrong ct, got %h", ciphertext); errors = errors + 1; end
        @(posedge clk);
        #1;
        if (ct_valid !== 1'b1) begin $display("FAIL T5c: ct_valid not asserted"); errors = errors + 1; end
        if (ciphertext !== 128'hf29000b62a499fd0a9f39a6add2e7780) begin $display("FAIL T5c: wrong ct, got %h", ciphertext); errors = errors + 1; end
        @(posedge clk);
        #1;
        if (ct_valid !== 1'b0) begin $display("FAIL T5: ct_valid still high after stream"); errors = errors + 1; end

        // ================================================================
        // Summary
        // ================================================================
        if (errors == 0)
            $display("[Top TB] PASSED");
        else
            $display("[Top TB] FAILED with %0d errors", errors);
        $finish;
    end

    always #1 clk = ~clk;
endmodule
