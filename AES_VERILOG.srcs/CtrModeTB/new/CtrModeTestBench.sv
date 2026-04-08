`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// CtrMode testbench.
//
// Test vectors from NIST SP 800-38A, Section F.5.5 (AES-256 CTR Encrypt)
// and F.5.6 (AES-256 CTR Decrypt — same operation).
//
// Key:       603deb1015ca71be2b73aef0857d7781
//            1f352c073b6108d72d9810a30914dff4
// Nonce/IV:  f0f1f2f3 f4f5f6f7 f8f9fafb (96 bits)
// Init CTR:  fcfdfeff (32 bits)
//
// Block 1:  PT = 6bc1bee22e409f96e93d7e117393172a
//           CT = 601ec313775789a5b7a7f504bbf3d228
// Block 2:  PT = ae2d8a571e03ac9c9eb76fac45af8e51
//           CT = f443e3ca4d62b59aca84e990cacaf5c5
// Block 3:  PT = 30c81c46a35ce411e5fbc1191a0a52ef
//           CT = 2b0930daa23de94ce87017ba2d84988d
// Block 4:  PT = f69f2445df4f9b17ad2b417be66c3710
//           CT = dfc9c58db67aada613c2dd08457941a6

module CtrModeTestBench;
    reg clk;
    reg rst;
    reg new_masterkey;
    reg [0:255] masterkey;
    wire [3:0] keys_ready;
    reg start_i;
    reg [0:95] nonce;
    reg [0:127] data_in;
    wire [0:127] data_out;
    wire out_valid;
    reg [0:31] counter_init;
    reg counter_load;
    wire [0:31] counter_val;

    CtrMode dut(
        .clk(clk),
        .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .keys_ready(keys_ready),
        .start_i(start_i),
        .nonce(nonce),
        .data_in(data_in),
        .data_out(data_out),
        .out_valid(out_valid),
        .counter_init(counter_init),
        .counter_load(counter_load),
        .counter_val(counter_val)
    );

    integer errors;

    // NIST test vectors
    reg [0:255] NIST_KEY;
    reg [0:95]  NIST_NONCE;
    reg [0:31]  NIST_CTR_INIT;
    reg [0:127] NIST_PT  [0:3];
    reg [0:127] NIST_CT  [0:3];

    initial begin
        NIST_KEY      = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
        NIST_NONCE    = 96'hf0f1f2f3f4f5f6f7f8f9fafb;
        NIST_CTR_INIT = 32'hfcfdfeff;
        NIST_PT[0]    = 128'h6bc1bee22e409f96e93d7e117393172a;
        NIST_PT[1]    = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        NIST_PT[2]    = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
        NIST_PT[3]    = 128'hf69f2445df4f9b17ad2b417be66c3710;
        NIST_CT[0]    = 128'h601ec313775789a5b7a7f504bbf3d228;
        NIST_CT[1]    = 128'hf443e3ca4d62b59aca84e990cacaf5c5;
        NIST_CT[2]    = 128'h2b0930daa23de94ce87017ba2d84988d;
        NIST_CT[3]    = 128'hdfc9c58db67aada613c2dd08457941a6;
    end

    always #5 clk = ~clk;

    integer i;

    initial begin
        $display("[CtrMode TB] Starting...");
        errors = 0;
        clk = 0;
        rst = 0;
        new_masterkey = 0;
        masterkey = '0;
        start_i = 0;
        nonce = '0;
        data_in = '0;
        counter_init = '0;
        counter_load = 0;

        // ── Reset ───────────────────────────────────────────
        @(posedge clk);
        rst = 1;
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ═════════════════════════════════════════════════════
        // Test 1: NIST SP 800-38A F.5.5 — AES-256 CTR Encrypt
        //         4 blocks, one at a time
        // ═════════════════════════════════════════════════════
        $display("  T1: NIST AES-256 CTR encrypt (4 blocks, sequential)");
        masterkey = NIST_KEY;
        new_masterkey = 1;
        @(posedge clk);
        #1; new_masterkey = 0;

        wait(keys_ready == 4'd15);
        @(posedge clk);

        // Load nonce and initial counter
        nonce = NIST_NONCE;
        counter_init = NIST_CTR_INIT;
        counter_load = 1;
        @(posedge clk);
        #1; counter_load = 0;

        // Process 4 blocks sequentially
        for (i = 0; i < 4; i = i + 1) begin
            data_in = NIST_PT[i];
            start_i = 1;
            @(posedge clk);
            #1; start_i = 0;
            data_in = '0;

            // Wait for out_valid
            wait(out_valid);
            #1;

            if (data_out !== NIST_CT[i]) begin
                $display("FAIL T1 block %0d: expected %h, got %h", i, NIST_CT[i], data_out);
                errors = errors + 1;
            end else begin
                $display("    Block %0d encrypt: PASS", i);
            end
            @(posedge clk); // advance past valid cycle
        end

        // Verify counter auto-incremented to init + 4
        if (counter_val !== (NIST_CTR_INIT + 32'd4)) begin
            $display("FAIL T1: counter expected %h, got %h", NIST_CTR_INIT + 32'd4, counter_val);
            errors = errors + 1;
        end

        // ═════════════════════════════════════════════════════
        // Test 2: CTR Decrypt (same operation) — feed ciphertext,
        //         expect plaintext back
        // ═════════════════════════════════════════════════════
        $display("  T2: NIST AES-256 CTR decrypt (same key, reload counter)");
        // Reload counter to initial value
        counter_init = NIST_CTR_INIT;
        counter_load = 1;
        @(posedge clk);
        #1; counter_load = 0;

        for (i = 0; i < 4; i = i + 1) begin
            data_in = NIST_CT[i];
            start_i = 1;
            @(posedge clk);
            #1; start_i = 0;
            data_in = '0;

            wait(out_valid);
            #1;

            if (data_out !== NIST_PT[i]) begin
                $display("FAIL T2 block %0d: expected %h, got %h", i, NIST_PT[i], data_out);
                errors = errors + 1;
            end else begin
                $display("    Block %0d decrypt: PASS", i);
            end
            @(posedge clk); // advance past valid cycle
        end

        // ═════════════════════════════════════════════════════
        // Test 3: Streaming — fire 4 blocks on consecutive cycles.
        //         Counter auto-increments each cycle.
        // ═════════════════════════════════════════════════════
        $display("  T3: NIST AES-256 CTR encrypt (4 blocks, streaming)");
        counter_init = NIST_CTR_INIT;
        counter_load = 1;
        @(posedge clk);
        #1; counter_load = 0;

        // Fire all 4 on consecutive cycles
        for (i = 0; i < 4; i = i + 1) begin
            data_in = NIST_PT[i];
            start_i = 1;
            @(posedge clk);
            #1;
        end
        start_i = 0;
        data_in = '0;

        // Wait for first result
        wait(out_valid);
        #1;

        // Collect 4 consecutive results
        for (i = 0; i < 4; i = i + 1) begin
            if (out_valid !== 1'b1) begin
                $display("FAIL T3: out_valid not asserted for block %0d", i);
                errors = errors + 1;
            end
            if (data_out !== NIST_CT[i]) begin
                $display("FAIL T3 block %0d: expected %h, got %h", i, NIST_CT[i], data_out);
                errors = errors + 1;
            end else begin
                $display("    Block %0d stream: PASS", i);
            end
            @(posedge clk);
            #1;
        end

        // ═════════════════════════════════════════════════════
        // Test 4: Zeroize — assert rst, verify counter and key
        //         expansion state are cleared
        // ═════════════════════════════════════════════════════
        $display("  T4: Zeroize");
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        #1;
        if (counter_val !== 32'd0) begin
            $display("FAIL T4: counter not zeroed, got %h", counter_val);
            errors = errors + 1;
        end
        if (keys_ready !== 4'd0) begin
            $display("FAIL T4: keys_ready not zeroed, got %d", keys_ready);
            errors = errors + 1;
        end
        $display("    Zeroize: PASS");

        // ═════════════════════════════════════════════════════
        // Summary
        // ═════════════════════════════════════════════════════
        repeat(5) @(posedge clk);
        if (errors == 0)
            $display("[CtrMode TB] ALL TESTS PASSED");
        else
            $display("[CtrMode TB] FAILED with %0d error(s)", errors);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("[CtrMode TB] TIMEOUT");
        $finish;
    end

endmodule
