`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// GFMult128 testbench
//////////////////////////////////////////////////////////////////////////////////

module GFMult128TestBench;
    reg clk;
    reg rst;
    reg start_i;
    reg [0:127] in_a;
    reg [0:127] in_b;
    wire [0:127] out_o;
    wire valid_o;

    GFMult128 dut(
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .in_a(in_a),
        .in_b(in_b),
        .out_o(out_o),
        .valid_o(valid_o)
    );

    reg [0:127] expected [0:255];
    integer wr_idx;
    integer rd_idx;
    integer errors;

    always #5 clk = ~clk;

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
        integer i;
        begin
            r = 128'he1000000000000000000000000000000;
            z = 128'd0;
            v = y;
            for (i = 0; i < 128; i = i + 1) begin
                if (x[i])
                    z = z ^ v;
                if (v[127] == 1'b0)
                    v = shift_right1_be(v);
                else
                    v = shift_right1_be(v) ^ r;
            end
            gf_mul_ref = z;
        end
    endfunction

    function automatic [0:127] rand128;
        input integer seed_base;
        begin
            rand128 = {$random(seed_base), $random(seed_base), $random(seed_base), $random(seed_base)};
        end
    endfunction

    task automatic submit_mul;
        input [0:127] a;
        input [0:127] b;
        begin
            expected[wr_idx] = gf_mul_ref(a, b);
            wr_idx = wr_idx + 1;
            in_a = a;
            in_b = b;
            start_i = 1'b1;
            @(posedge clk);
            #1;
            start_i = 1'b0;
            in_a = '0;
            in_b = '0;
        end
    endtask

    integer seed;
    integer i;
    reg [0:127] a_tmp;
    reg [0:127] b_tmp;

    initial begin
        $display("[GFMult128 TB] Starting...");
        clk = 0;
        rst = 0;
        start_i = 0;
        in_a = '0;
        in_b = '0;
        wr_idx = 0;
        rd_idx = 0;
        errors = 0;
        seed = 32'h12345678;

        @(posedge clk);
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;
        @(negedge clk);

        // Test 1: Known GHASH vector (single multiply)
        // X = 0388dace60b6a392f328c2b971b2fe78
        // H = 66e94bd4ef8a2c3b884cfa59ca342b2e
        submit_mul(
            128'h0388dace60b6a392f328c2b971b2fe78,
            128'h66e94bd4ef8a2c3b884cfa59ca342b2e
        );

        // Test 2: Back-to-back random operations (throughput)
        for (i = 0; i < 32; i = i + 1) begin
            a_tmp = rand128(seed + i * 17);
            b_tmp = rand128(seed + i * 31 + 7);
            submit_mul(a_tmp, b_tmp);
        end

        // Drain pipeline
        repeat (8) @(posedge clk);

        if (rd_idx != wr_idx) begin
            $display("FAIL: expected %0d results, observed %0d", wr_idx, rd_idx);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("[GFMult128 TB] ALL TESTS PASSED");
        else
            $display("[GFMult128 TB] FAILED with %0d error(s)", errors);

        $finish;
    end

    always @(posedge clk) begin
        if (valid_o) begin
            if (out_o !== expected[rd_idx]) begin
                $display("FAIL result %0d: expected %h, got %h", rd_idx, expected[rd_idx], out_o);
                errors <= errors + 1;
            end
            rd_idx <= rd_idx + 1;
        end
    end

    initial begin
        repeat (10000) @(posedge clk);
        $display("FAIL: Timeout");
        $finish;
    end

endmodule
