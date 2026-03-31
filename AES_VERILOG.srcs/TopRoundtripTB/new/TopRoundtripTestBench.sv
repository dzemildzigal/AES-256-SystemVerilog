`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// TopRoundtrip testbench: KeyExpansion + Encrypt -> Decrypt roundtrip.
// Verifies match flag, intermediate ciphertext, and final decrypted result.

module TopRoundtripTestBench;
    reg clk;
    reg rst;
    reg new_masterkey;
    reg [0:255] masterkey;
    wire [3:0] keys_ready;
    reg start_i;
    reg [0:127] plaintext;
    wire [0:127] ct_latched;
    wire [0:127] result;
    wire busy;
    wire result_valid;
    wire match;

    TopRoundtrip dut(
        .clk(clk),
        .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .keys_ready(keys_ready),
        .start_i(start_i),
        .plaintext(plaintext),
        .ct_latched(ct_latched),
        .result(result),
        .busy(busy),
        .result_valid(result_valid),
        .match(match)
    );

    integer errors;

    initial begin
        $display("[TopRoundtrip TB] Starting...");
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
        // Test 1: All-zero key, zero plaintext roundtrip
        // ================================================================
        $display("  T1: zero key, zero plaintext roundtrip");
        masterkey = 256'h0;
        new_masterkey = 1;
        @(posedge clk);
        #1; new_masterkey = 0;

        wait(keys_ready == 4'd15);
        @(posedge clk);

        plaintext = 128'h00000000000000000000000000000000;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        plaintext = '0;

        // Wait for roundtrip: 30 cycles (15 encrypt + 15 decrypt + latch)
        repeat(30) @(posedge clk);
        #1;
        if (result_valid !== 1'b1) begin $display("FAIL T1: result_valid not asserted"); errors = errors + 1; end
        if (match !== 1'b1) begin $display("FAIL T1: match not set"); errors = errors + 1; end
        if (result !== 128'h00000000000000000000000000000000) begin $display("FAIL T1: wrong result, got %h", result); errors = errors + 1; end
        if (ct_latched !== 128'hdc95c078a2408989ad48a21492842087) begin $display("FAIL T1: wrong ct, got %h", ct_latched); errors = errors + 1; end

        @(posedge clk);
        #1;
        if (busy !== 1'b0) begin $display("FAIL T1: busy should be 0"); errors = errors + 1; end

        // ================================================================
        // Test 2: NIST AES-256 key, NIST plaintext roundtrip
        // ================================================================
        $display("  T2: NIST key, NIST plaintext roundtrip");
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

        repeat(30) @(posedge clk);
        #1;
        if (result_valid !== 1'b1) begin $display("FAIL T2: result_valid not asserted"); errors = errors + 1; end
        if (match !== 1'b1) begin $display("FAIL T2: match not set"); errors = errors + 1; end
        if (result !== 128'h00112233445566778899aabbccddeeff) begin $display("FAIL T2: wrong result, got %h", result); errors = errors + 1; end
        if (ct_latched !== 128'h8ea2b7ca516745bfeafc49904b496089) begin $display("FAIL T2: wrong ct, got %h", ct_latched); errors = errors + 1; end

        // ================================================================
        // Test 3: Custom key, "Hello world!  :)" roundtrip
        // ================================================================
        $display("  T3: custom key, Hello world roundtrip");
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

        repeat(30) @(posedge clk);
        #1;
        if (result_valid !== 1'b1) begin $display("FAIL T3: result_valid not asserted"); errors = errors + 1; end
        if (match !== 1'b1) begin $display("FAIL T3: match not set"); errors = errors + 1; end
        if (result !== 128'h48656c6c6f20776f726c642120203a29) begin $display("FAIL T3: wrong result, got %h", result); errors = errors + 1; end
        if (ct_latched !== 128'hea1044c3b1139b6cf71095be1071b90d) begin $display("FAIL T3: wrong ct, got %h", ct_latched); errors = errors + 1; end

        // ================================================================
        // Test 4: Busy signal — start_i ignored while busy
        // ================================================================
        $display("  T4: busy rejection test");
        // Reuse last key (already expanded)
        plaintext = 128'hdeadbeefdeadbeefdeadbeefdeadbeef;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;

        // Try to start another operation while busy
        repeat(5) @(posedge clk);
        #1;
        if (busy !== 1'b1) begin $display("FAIL T4: should be busy"); errors = errors + 1; end
        plaintext = 128'h11111111111111111111111111111111;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;

        // Wait for original to finish
        repeat(25) @(posedge clk);
        #1;
        if (result_valid !== 1'b1) begin $display("FAIL T4: result_valid not asserted"); errors = errors + 1; end
        if (match !== 1'b1) begin $display("FAIL T4: match not set (original should match)"); errors = errors + 1; end
        if (result !== 128'hdeadbeefdeadbeefdeadbeefdeadbeef) begin $display("FAIL T4: wrong result, got %h", result); errors = errors + 1; end

        // ================================================================
        // Summary
        // ================================================================
        if (errors == 0)
            $display("[TopRoundtrip TB] PASSED");
        else
            $display("[TopRoundtrip TB] FAILED with %0d errors", errors);
        $finish;
    end

    always #1 clk = ~clk;
endmodule
