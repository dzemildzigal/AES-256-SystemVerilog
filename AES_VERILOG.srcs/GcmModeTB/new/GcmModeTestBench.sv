`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// GcmMode integration testbench
//////////////////////////////////////////////////////////////////////////////////

module GcmModeTestBench;
    // ----------------------------------------------------------------
    // DUT signals
    // ----------------------------------------------------------------
    reg clk;
    reg rst;

    reg         new_masterkey;
    reg [0:255] masterkey;
    wire [3:0]  keys_ready;

    reg         session_start_i;
    reg [0:95]  nonce_i;
    reg [0:63]  aad_len_bits_i;
    reg [0:63]  pt_len_bits_i;
    wire        session_ready_o;

    reg [0:127] aad_data_i;
    reg         aad_valid_i;
    reg         aad_last_i;
    wire        aad_ready_o;

    reg [0:127] pt_data_i;
    reg         pt_valid_i;
    reg         pt_last_i;
    wire        pt_ready_o;

    wire [0:127] ct_data_o;
    wire         ct_valid_o;
    wire         ct_last_o;

    wire [0:127] ghash_out_o;
    wire         ghash_valid_o;
    wire [0:127] tag_out_o;
    wire         tag_valid_o;

    wire [0:31]  counter_val_o;
    wire         h_valid_o;
    wire         busy_o;

    GcmMode dut(
        .clk(clk),
        .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .keys_ready(keys_ready),
        .session_start_i(session_start_i),
        .nonce_i(nonce_i),
        .aad_len_bits_i(aad_len_bits_i),
        .pt_len_bits_i(pt_len_bits_i),
        .session_ready_o(session_ready_o),
        .aad_data_i(aad_data_i),
        .aad_valid_i(aad_valid_i),
        .aad_last_i(aad_last_i),
        .aad_ready_o(aad_ready_o),
        .pt_data_i(pt_data_i),
        .pt_valid_i(pt_valid_i),
        .pt_last_i(pt_last_i),
        .pt_ready_o(pt_ready_o),
        .ct_data_o(ct_data_o),
        .ct_valid_o(ct_valid_o),
        .ct_last_o(ct_last_o),
        .ghash_out_o(ghash_out_o),
        .ghash_valid_o(ghash_valid_o),
        .tag_out_o(tag_out_o),
        .tag_valid_o(tag_valid_o),
        .counter_val_o(counter_val_o),
        .h_valid_o(h_valid_o),
        .busy_o(busy_o)
    );

    // ----------------------------------------------------------------
    // Independent reference AES path
    // ----------------------------------------------------------------
    reg         ref_new_masterkey;
    reg [0:255] ref_masterkey;
    wire [0:1919] ref_w;
    wire [3:0]    ref_keys_ready;

    reg         ref_start;
    reg [0:127] ref_in;
    wire [0:127] ref_out;
    wire         ref_valid;

    KeyExpansion ke_ref(
        .clk(clk),
        .rst(rst),
        .new_masterkey(ref_new_masterkey),
        .masterkey(ref_masterkey),
        .w(ref_w),
        .keys_ready(ref_keys_ready)
    );

    EncryptPipelined ep_ref(
        .clk(clk),
        .rst(rst),
        .start_i(ref_start),
        .in(ref_in),
        .expanded_key(ref_w),
        .out(ref_out),
        .valid_data(ref_valid)
    );

    // ----------------------------------------------------------------
    // Local storage
    // ----------------------------------------------------------------
    reg [0:127] aad_blk [0:15];
    reg [0:127] pt_blk  [0:31];
    reg [0:127] exp_ct  [0:31];
    reg [0:127] got_ct  [0:31];

    integer exp_ct_n;
    integer got_ct_n;
    integer errors;
    integer i;

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    always #5 clk = ~clk;

    // Capture DUT ciphertext stream
    always @(posedge clk) begin
        if (ct_valid_o) begin
            got_ct[got_ct_n] = ct_data_o;
            got_ct_n = got_ct_n + 1;
        end
    end

    // ----------------------------------------------------------------
    // GHASH reference helpers
    // ----------------------------------------------------------------
    function automatic [0:127] shift_right1_be;
        input [0:127] data;
        reg [0:127] tmp;
        integer j;
        begin
            tmp[0] = 1'b0;
            for (j = 1; j < 128; j = j + 1)
                tmp[j] = data[j-1];
            shift_right1_be = tmp;
        end
    endfunction

    function automatic [0:127] gf_mul_ref;
        input [0:127] x;
        input [0:127] y;
        reg [0:127] z;
        reg [0:127] v;
        reg [0:127] r;
        integer k;
        begin
            r = 128'he1000000000000000000000000000000;
            z = 128'd0;
            v = y;
            for (k = 0; k < 128; k = k + 1) begin
                if (x[k])
                    z = z ^ v;
                if (v[127] == 1'b0)
                    v = shift_right1_be(v);
                else
                    v = shift_right1_be(v) ^ r;
            end
            gf_mul_ref = z;
        end
    endfunction

    // ----------------------------------------------------------------
    // Utility tasks
    // ----------------------------------------------------------------
    task automatic clear_inputs;
        begin
            new_masterkey     = 1'b0;
            masterkey         = '0;
            session_start_i   = 1'b0;
            nonce_i           = '0;
            aad_len_bits_i    = '0;
            pt_len_bits_i     = '0;
            aad_data_i        = '0;
            aad_valid_i       = 1'b0;
            aad_last_i        = 1'b0;
            pt_data_i         = '0;
            pt_valid_i        = 1'b0;
            pt_last_i         = 1'b0;

            ref_new_masterkey = 1'b0;
            ref_masterkey     = '0;
            ref_start         = 1'b0;
            ref_in            = '0;
        end
    endtask

    task automatic apply_reset;
        begin
            clear_inputs();
            rst = 1'b1;
            repeat (3) @(posedge clk);
            #1;
            rst = 1'b0;
            repeat (2) @(posedge clk);
            #1;
        end
    endtask

    task automatic load_ref_key;
        input [0:255] key;
        begin
            ref_masterkey     = key;
            ref_new_masterkey = 1'b1;
            @(posedge clk);
            #1;
            ref_new_masterkey = 1'b0;
            wait (ref_keys_ready == 4'd15);
            @(posedge clk);
            #1;
        end
    endtask

    task automatic ref_encrypt_block;
        input  [0:127] blk;
        output [0:127] enc;
        begin
            ref_in    = blk;
            ref_start = 1'b1;
            @(posedge clk);
            #1;
            ref_start = 1'b0;
            ref_in    = '0;

            wait (ref_valid);
            #1;
            enc = ref_out;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic compute_expected;
        input  [0:255] key;
        input  [0:95]  nonce;
        input  integer aad_n;
        input  integer pt_n;
        output [0:127] exp_ghash;
        output [0:127] exp_tag;

        reg [0:127] h_ref;
        reg [0:127] tag_mask_ref;
        reg [0:127] ks;
        reg [0:127] y;
        reg [0:127] len_blk;
        reg [0:63]  aad_bits;
        reg [0:63]  pt_bits;
        reg [31:0]  ctr_word;
        integer k;
        begin
            load_ref_key(key);

            ref_encrypt_block(128'd0, h_ref);
            ref_encrypt_block({nonce, 32'h00000001}, tag_mask_ref);

            for (k = 0; k < pt_n; k = k + 1) begin
                ctr_word = 32'd2 + k[31:0];
                ref_encrypt_block({nonce, ctr_word}, ks);
                exp_ct[k] = pt_blk[k] ^ ks;
            end

            y = 128'd0;
            for (k = 0; k < aad_n; k = k + 1)
                y = gf_mul_ref(y ^ aad_blk[k], h_ref);
            for (k = 0; k < pt_n; k = k + 1)
                y = gf_mul_ref(y ^ exp_ct[k], h_ref);

            aad_bits = aad_n * 64'd128;
            pt_bits  = pt_n  * 64'd128;
            len_blk  = {aad_bits, pt_bits};
            y        = gf_mul_ref(y ^ len_blk, h_ref);

            exp_ghash = y;
            exp_tag   = y ^ tag_mask_ref;
        end
    endtask

    task automatic load_dut_key;
        input [0:255] key;
        begin
            masterkey     = key;
            new_masterkey = 1'b1;
            @(posedge clk);
            #1;
            new_masterkey = 1'b0;
        end
    endtask

    task automatic start_dut_session;
        input [0:95]  nonce;
        input integer aad_n;
        input integer pt_n;
        begin
            wait (h_valid_o == 1'b1);
            wait (session_ready_o == 1'b1);
            #1;
            nonce_i         = nonce;
            aad_len_bits_i  = aad_n * 64'd128;
            pt_len_bits_i   = pt_n  * 64'd128;
            session_start_i = 1'b1;
            @(posedge clk);
            #1;
            session_start_i = 1'b0;
        end
    endtask

    task automatic send_aad_block;
        input [0:127] blk;
        input         is_last;
        begin
            while (!aad_ready_o)
                @(posedge clk);
            #1;
            aad_data_i  = blk;
            aad_valid_i = 1'b1;
            aad_last_i  = is_last;
            @(posedge clk);
            #1;
            aad_valid_i = 1'b0;
            aad_last_i  = 1'b0;
            aad_data_i  = '0;
        end
    endtask

    task automatic send_pt_block;
        input [0:127] blk;
        input         is_last;
        begin
            while (!pt_ready_o)
                @(posedge clk);
            #1;
            pt_data_i  = blk;
            pt_valid_i = 1'b1;
            pt_last_i  = is_last;
            @(posedge clk);
            #1;
            pt_valid_i = 1'b0;
            pt_last_i  = 1'b0;
            pt_data_i  = '0;
        end
    endtask

    task automatic wait_for_tag;
        input integer timeout_cycles;
        integer t;
        begin
            t = timeout_cycles;
            while ((tag_valid_o !== 1'b1) && (t > 0)) begin
                @(posedge clk);
                t = t - 1;
            end
            if (t == 0) begin
                $display("FAIL: timeout waiting for tag_valid_o");
                errors = errors + 1;
            end
            #1;
        end
    endtask

    task automatic compare_results;
        input [0:127] exp_ghash;
        input [0:127] exp_tag;
        input integer pt_n;
        input [255:0] test_name;
        integer k;
        begin
            if (got_ct_n != pt_n) begin
                $display("FAIL %0s: ciphertext count expected %0d, got %0d", test_name, pt_n, got_ct_n);
                errors = errors + 1;
            end

            for (k = 0; k < pt_n; k = k + 1) begin
                if (got_ct[k] !== exp_ct[k]) begin
                    $display("FAIL %0s CT[%0d]: expected %h, got %h", test_name, k, exp_ct[k], got_ct[k]);
                    errors = errors + 1;
                end
            end

            if (ghash_out_o !== exp_ghash) begin
                $display("FAIL %0s GHASH: expected %h, got %h", test_name, exp_ghash, ghash_out_o);
                errors = errors + 1;
            end

            if (tag_out_o !== exp_tag) begin
                $display("FAIL %0s TAG: expected %h, got %h", test_name, exp_tag, tag_out_o);
                errors = errors + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Main stimulus
    // ----------------------------------------------------------------
    reg [0:255] key_t;
    reg [0:95]  nonce_t;
    reg [0:127] exp_ghash_t;
    reg [0:127] exp_tag_t;

    initial begin
        $display("[GcmMode TB] Starting...");
        clk = 1'b0;
        rst = 1'b0;
        errors = 0;
        got_ct_n = 0;
        exp_ct_n = 0;

        // =========================
        // T1: no AAD, 2 PT blocks
        // =========================
        apply_reset();

        key_t   = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
        nonce_t = 96'hcafebabefacedbaddecaf888;

        exp_ct_n = 2;
        aad_blk[0] = '0;
        pt_blk[0] = 128'h00112233445566778899aabbccddeeff;
        pt_blk[1] = 128'hffeeddccbbaa99887766554433221100;

        compute_expected(key_t, nonce_t, 0, exp_ct_n, exp_ghash_t, exp_tag_t);

        got_ct_n = 0;
        load_dut_key(key_t);
        start_dut_session(nonce_t, 0, exp_ct_n);

        send_pt_block(pt_blk[0], 1'b0);
        send_pt_block(pt_blk[1], 1'b1);

        wait_for_tag(4000);
        compare_results(exp_ghash_t, exp_tag_t, exp_ct_n, "T1");

        // ====================================
        // T2: 2 AAD blocks, 3 PT blocks
        // ====================================
        apply_reset();

        key_t   = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
        nonce_t = 96'hf0f1f2f3f4f5f6f7f8f9fafb;

        aad_blk[0] = 128'hfeedfacedeadbeeffeedfacedeadbeef;
        aad_blk[1] = 128'habaddad2000000000000000000000001;

        exp_ct_n = 3;
        pt_blk[0] = 128'h6bc1bee22e409f96e93d7e117393172a;
        pt_blk[1] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        pt_blk[2] = 128'h30c81c46a35ce411e5fbc1191a0a52ef;

        compute_expected(key_t, nonce_t, 2, exp_ct_n, exp_ghash_t, exp_tag_t);

        got_ct_n = 0;
        load_dut_key(key_t);
        start_dut_session(nonce_t, 2, exp_ct_n);

        send_aad_block(aad_blk[0], 1'b0);
        send_aad_block(aad_blk[1], 1'b1);

        send_pt_block(pt_blk[0], 1'b0);
        send_pt_block(pt_blk[1], 1'b0);
        send_pt_block(pt_blk[2], 1'b1);

        wait_for_tag(6000);
        compare_results(exp_ghash_t, exp_tag_t, exp_ct_n, "T2");

        if (errors == 0)
            $display("[GcmMode TB] ALL TESTS PASSED");
        else
            $display("[GcmMode TB] FAILED with %0d error(s)", errors);

        $finish;
    end

    initial begin
        repeat (60000) @(posedge clk);
        $display("[GcmMode TB] FAILED: TIMEOUT");
        $finish;
    end

endmodule
