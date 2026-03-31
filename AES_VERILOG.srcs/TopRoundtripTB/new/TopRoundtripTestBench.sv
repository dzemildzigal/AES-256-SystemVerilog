`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// TopRoundtrip testbench: streaming pipeline verification.
// Tests single-shot roundtrip AND continuous streaming throughput.

module TopRoundtripTestBench;
    reg clk;
    reg rst;
    reg new_masterkey;
    reg [0:255] masterkey;
    wire [3:0] keys_ready;
    reg start_i;
    reg [0:127] plaintext;
    wire [0:127] ct_out;
    wire         ct_valid;
    wire [0:127] result;
    wire         result_valid;
    wire         match;

    TopRoundtrip dut(
        .clk(clk),
        .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .keys_ready(keys_ready),
        .start_i(start_i),
        .plaintext(plaintext),
        .ct_out(ct_out),
        .ct_valid(ct_valid),
        .result(result),
        .result_valid(result_valid),
        .match(match)
    );

    integer errors;
    integer i;

    // Expected plaintexts for streaming test (T4): 8 blocks
    reg [0:127] stream_pt [0:7];
    // Collect results in order
    reg [0:127] stream_res [0:7];
    integer res_idx;

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
        // Test 1: All-zero key, zero plaintext single-shot roundtrip
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

        // Wait for result: 30 pipeline cycles (29 internal + 1 output register)
        repeat(30) @(posedge clk);
        #1;
        if (result_valid !== 1'b1) begin $display("FAIL T1: result_valid not asserted"); errors = errors + 1; end
        if (match !== 1'b1) begin $display("FAIL T1: match not set"); errors = errors + 1; end
        if (result !== 128'h00000000000000000000000000000000) begin $display("FAIL T1: wrong result, got %h", result); errors = errors + 1; end

        // Check intermediate ct was valid 15 cycles earlier
        // (ct_valid would have pulsed; ct_out holds the value from that cycle's output register)

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

        // ================================================================
        // Test 4: Streaming — fire 8 blocks on consecutive cycles, then
        //         verify all 8 results arrive on 8 consecutive cycles,
        //         each with match=1.
        // ================================================================
        $display("  T4: streaming 8 back-to-back blocks");
        // Reuse last key (already expanded)
        stream_pt[0] = 128'h00000000000000000000000000000001;
        stream_pt[1] = 128'h00000000000000000000000000000002;
        stream_pt[2] = 128'h00000000000000000000000000000003;
        stream_pt[3] = 128'hdeadbeefdeadbeefdeadbeefdeadbeef;
        stream_pt[4] = 128'hcafebabeCAFEBABEcafebabeCAFEBABE;
        stream_pt[5] = 128'h0123456789abcdef0123456789abcdef;
        stream_pt[6] = 128'hfedcba9876543210fedcba9876543210;
        stream_pt[7] = 128'hffffffffffffffffffffffffffffffff;

        // Fire all 8 on consecutive cycles
        for (i = 0; i < 8; i = i + 1) begin
            plaintext = stream_pt[i];
            start_i = 1;
            @(posedge clk);
            #1;
        end
        start_i = 0;
        plaintext = '0;

        // Wait for first result. Block 0 sampled at posedge 0 of the for loop.
        // Internal pipeline: 29 cycles (dec_valid at posedge 29).
        // Output register: +1 cycle (result_valid at posedge 30).
        // We consumed 8 posedges in the loop, need 30-8=22 more to reach
        // posedge 30 relative to block 0.  BUT the for loop ends at
        // posedge 7 + #1 (the 8th posedge from block 0 is posedge 7,
        // since block 0 is posedge 0). repeat(22) goes to posedge 29.
        // Need 1 more to reach posedge 30.
        repeat(23) @(posedge clk);
        #1;

        // Now collect 8 consecutive results
        res_idx = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (result_valid !== 1'b1) begin
                $display("FAIL T4: result_valid not asserted for block %0d", i);
                errors = errors + 1;
            end
            if (match !== 1'b1) begin
                $display("FAIL T4: match not set for block %0d", i);
                errors = errors + 1;
            end
            if (result !== stream_pt[i]) begin
                $display("FAIL T4: block %0d mismatch, expected %h got %h", i, stream_pt[i], result);
                errors = errors + 1;
            end
            stream_res[i] = result;
            @(posedge clk);
            #1;
        end

        // After last result, result_valid should drop
        if (result_valid !== 1'b0) begin
            $display("FAIL T4: result_valid should be 0 after stream ends");
            errors = errors + 1;
        end

        // ================================================================
        // Test 5: start_i ignored when keys not ready (during key expansion)
        // ================================================================
        $display("  T5: start_i rejected during key expansion");
        masterkey = 256'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
        new_masterkey = 1;
        @(posedge clk);
        #1; new_masterkey = 0;

        // Immediately try to start while keys are expanding
        plaintext = 128'h11111111111111111111111111111111;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;

        // Wait enough cycles — result_valid should NOT fire for this stale attempt
        repeat(35) @(posedge clk);
        #1;
        // result_valid should still be 0 (the gated_start blocked it)
        if (result_valid !== 1'b0) begin
            $display("FAIL T5: result_valid should be 0 (start was rejected)");
            errors = errors + 1;
        end

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
