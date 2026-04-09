`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// GHashEngine testbench
//////////////////////////////////////////////////////////////////////////////////

module GHashEngineTestBench;
    reg clk;
    reg rst;

    reg         start_i;
    reg [0:127] h_i;
    reg [0:127] tag_mask_i;
    reg [0:63]  aad_len_bits_i;
    reg [0:63]  ct_len_bits_i;

    reg [0:127] aad_data_i;
    reg         aad_valid_i;
    reg         aad_last_i;
    wire        aad_ready_o;

    reg [0:127] ct_data_i;
    reg         ct_valid_i;
    reg         ct_last_i;
    wire        ct_ready_o;

    wire        ready_o;
    wire        busy_o;
    wire [0:127] ghash_out_o;
    wire        ghash_valid_o;
    wire [0:127] tag_out_o;
    wire        tag_valid_o;

    GHashEngine dut(
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .h_i(h_i),
        .tag_mask_i(tag_mask_i),
        .aad_len_bits_i(aad_len_bits_i),
        .ct_len_bits_i(ct_len_bits_i),
        .aad_data_i(aad_data_i),
        .aad_valid_i(aad_valid_i),
        .aad_last_i(aad_last_i),
        .aad_ready_o(aad_ready_o),
        .ct_data_i(ct_data_i),
        .ct_valid_i(ct_valid_i),
        .ct_last_i(ct_last_i),
        .ct_ready_o(ct_ready_o),
        .ready_o(ready_o),
        .busy_o(busy_o),
        .ghash_out_o(ghash_out_o),
        .ghash_valid_o(ghash_valid_o),
        .tag_out_o(tag_out_o),
        .tag_valid_o(tag_valid_o)
    );

    always #5 clk = ~clk;

    integer errors;
    integer i;

    reg [0:127] aad_vec [0:31];
    reg [0:127] ct_vec  [0:63];
    integer aad_n;
    integer ct_n;

    reg [0:127] h_cur;
    reg [0:127] tag_mask_cur;
    reg [0:63]  aad_len_bits_cur;
    reg [0:63]  ct_len_bits_cur;

    reg [0:127] exp_ghash;
    reg [0:127] exp_tag;

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

    task automatic compute_expected;
        reg [0:127] y;
        begin
            y = 128'd0;
            for (i = 0; i < aad_n; i = i + 1)
                y = gf_mul_ref(y ^ aad_vec[i], h_cur);
            for (i = 0; i < ct_n; i = i + 1)
                y = gf_mul_ref(y ^ ct_vec[i], h_cur);
            y = gf_mul_ref(y ^ {aad_len_bits_cur, ct_len_bits_cur}, h_cur);
            exp_ghash = y;
            exp_tag = y ^ tag_mask_cur;
        end
    endtask

    task automatic start_session;
        begin
            while (!ready_o)
                @(posedge clk);
            #1;
            h_i            = h_cur;
            tag_mask_i     = tag_mask_cur;
            aad_len_bits_i = aad_len_bits_cur;
            ct_len_bits_i  = ct_len_bits_cur;
            start_i        = 1'b1;
            @(posedge clk);
            #1;
            start_i        = 1'b0;
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

    task automatic send_ct_block;
        input [0:127] blk;
        input         is_last;
        begin
            while (!ct_ready_o)
                @(posedge clk);
            #1;
            ct_data_i  = blk;
            ct_valid_i = 1'b1;
            ct_last_i  = is_last;
            @(posedge clk);
            #1;
            ct_valid_i = 1'b0;
            ct_last_i  = 1'b0;
            ct_data_i  = '0;
        end
    endtask

    task automatic wait_and_check;
        input [255:0] name;
        integer timeout;
        begin
            timeout = 5000;
            while (!tag_valid_o && timeout > 0) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            #1;
            if (timeout == 0) begin
                $display("FAIL %0s: timeout waiting for tag_valid", name);
                errors = errors + 1;
            end
            else begin
                if (ghash_out_o !== exp_ghash) begin
                    $display("FAIL %0s GHASH: expected %h, got %h", name, exp_ghash, ghash_out_o);
                    errors = errors + 1;
                end
                if (tag_out_o !== exp_tag) begin
                    $display("FAIL %0s TAG: expected %h, got %h", name, exp_tag, tag_out_o);
                    errors = errors + 1;
                end
            end
            @(posedge clk);
        end
    endtask

    initial begin
        $display("[GHashEngine TB] Starting...");
        clk = 0;
        rst = 0;

        start_i = 0;
        h_i = '0;
        tag_mask_i = '0;
        aad_len_bits_i = '0;
        ct_len_bits_i = '0;

        aad_data_i = '0;
        aad_valid_i = 0;
        aad_last_i = 0;
        ct_data_i = '0;
        ct_valid_i = 0;
        ct_last_i = 0;

        errors = 0;

        @(posedge clk);
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ------------------------------------------------------------
        // T1: 1 AAD block + 1 CT block
        // ------------------------------------------------------------
        h_cur            = 128'h66e94bd4ef8a2c3b884cfa59ca342b2e;
        tag_mask_cur     = 128'h58e2fccefa7e3061367f1d57a4e7455a;
        aad_n            = 1;
        ct_n             = 1;
        aad_len_bits_cur = 64'd128;
        ct_len_bits_cur  = 64'd128;

        aad_vec[0]       = 128'hfeedfacedeadbeeffeedfacedeadbeef;
        ct_vec[0]        = 128'h42831ec2217774244b7221b784d0d49c;

        compute_expected();
        start_session();
        send_aad_block(aad_vec[0], 1'b1);
        send_ct_block(ct_vec[0], 1'b1);
        wait_and_check("T1");

        // ------------------------------------------------------------
        // T2: 0 AAD + 3 CT blocks (tail batch path)
        // ------------------------------------------------------------
        h_cur            = 128'hb83b533708bf535d0aa6e52980d53b78;
        tag_mask_cur     = 128'h7f1b32b81b820d02614f8895ac1d4eac;
        aad_n            = 0;
        ct_n             = 3;
        aad_len_bits_cur = 64'd0;
        ct_len_bits_cur  = 64'd384;

        ct_vec[0]        = 128'h11111111111111111111111111111111;
        ct_vec[1]        = 128'h22222222222222222222222222222222;
        ct_vec[2]        = 128'h33333333333333333333333333333333;

        compute_expected();
        start_session();
        send_ct_block(ct_vec[0], 1'b0);
        send_ct_block(ct_vec[1], 1'b0);
        send_ct_block(ct_vec[2], 1'b1);
        wait_and_check("T2");

        // ------------------------------------------------------------
        // T3: 5 AAD + 7 CT blocks (multi-batch stream)
        // ------------------------------------------------------------
        h_cur            = 128'h0f0e0d0c0b0a09080706050403020100;
        tag_mask_cur     = 128'h00112233445566778899aabbccddeeff;
        aad_n            = 5;
        ct_n             = 7;
        aad_len_bits_cur = 64'd640;
        ct_len_bits_cur  = 64'd896;

        for (i = 0; i < aad_n; i = i + 1)
            aad_vec[i] = 128'h10000000000000000000000000000000 ^ i;

        for (i = 0; i < ct_n; i = i + 1)
            ct_vec[i] = 128'h20000000000000000000000000000000 ^ (i * 32'h01020304);

        compute_expected();
        start_session();

        for (i = 0; i < aad_n; i = i + 1)
            send_aad_block(aad_vec[i], (i == aad_n - 1));

        for (i = 0; i < ct_n; i = i + 1)
            send_ct_block(ct_vec[i], (i == ct_n - 1));

        wait_and_check("T3");

        if (errors == 0)
            $display("[GHashEngine TB] ALL TESTS PASSED");
        else
            $display("[GHashEngine TB] FAILED with %0d error(s)", errors);

        $finish;
    end

    initial begin
        repeat (30000) @(posedge clk);
        $display("FAIL: Timeout");
        $finish;
    end

endmodule
