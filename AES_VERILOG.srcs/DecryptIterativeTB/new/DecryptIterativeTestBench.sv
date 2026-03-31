`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module DecryptIterativeTestBench;
    reg clk;
    reg rst;
    reg start_i;
    reg [0:127] in;
    reg [0:1919] expanded_key;

    wire [0:127] out;
    wire valid_data;

    Decrypt decrypt(
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .in(in),
        .expanded_key(expanded_key),
        .out(out),
        .valid_data(valid_data)
    );

    integer errors;

    initial begin
        $display("[Decrypt Iterative TB] Starting...");
        errors = 0;
        clk = 0;
        rst = 0;
        start_i = 0;
        @(posedge clk);
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        #1;

        // ---- Vector 1: all-zero key, ct -> pt=0 ----
        expanded_key = 1920'h000000000000000000000000000000000000000000000000000000000000000062636363626363636263636362636363aafbfbfbaafbfbfbaafbfbfbaafbfbfb6f6c6ccf0d0f0fac6f6c6ccf0d0f0fac7d8d8d6ad77676917d8d8d6ad77676915354edc15e5be26d31378ea23c38810e968a81c141fcf7503c717a3aeb070cab9eaa8f28c0f16d45f1c6e3e7cdfe62e92b312bdf6acddc8f56bca6b5bdbbaa1e6406fd52a4f79017553173f098cf11196dbba90b0776758451cad331ec71792fe7b0e89c4347788b16760b7b8eb91a6274ed0ba1739b7e252251ad14ce20d43b10f80a1753bf729c45c979e7cb706385;
        in = 128'hdc95c078a2408989ad48a21492842087;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        if (valid_data !== 1'b1) begin $display("FAIL V1: valid_data not asserted"); errors = errors + 1; end
        if (out !== 128'h00000000000000000000000000000000) begin $display("FAIL V1: wrong pt, got %h", out); errors = errors + 1; end

        @(posedge clk);
        #1;

        // ---- Vector 2: NIST key, ct -> pt=0 ----
        expanded_key = 1920'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1fa573c29fa176c498a97fce93a572c09c1651a8cd0244beda1a5da4c10640badeae87dff00ff11b68a68ed5fb03fc15676de1f1486fa54f9275f8eb5373b8518dc656827fc9a799176f294cec6cd5598b3de23a75524775e727bf9eb45407cf390bdc905fc27b0948ad5245a4c1871c2f45f5a66017b2d387300d4d33640a820a7ccff71cbeb4fe5413e6bbf0d261a7dff01afafee7a82979d7a5644ab3afe6402541fe719bf500258813bbd55a721c0a4e5a6699a9f24fe07e572baacdf8cdea24fc79ccbf0979e9371ac23c6d68de36;
        in = 128'hf29000b62a499fd0a9f39a6add2e7780;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        if (valid_data !== 1'b1) begin $display("FAIL V2: valid_data not asserted"); errors = errors + 1; end
        if (out !== 128'h00000000000000000000000000000000) begin $display("FAIL V2: wrong pt, got %h", out); errors = errors + 1; end

        @(posedge clk);
        #1;

        // ---- Vector 3: NIST key, ct -> pt=00112233..eeff ----
        expanded_key = 1920'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1fa573c29fa176c498a97fce93a572c09c1651a8cd0244beda1a5da4c10640badeae87dff00ff11b68a68ed5fb03fc15676de1f1486fa54f9275f8eb5373b8518dc656827fc9a799176f294cec6cd5598b3de23a75524775e727bf9eb45407cf390bdc905fc27b0948ad5245a4c1871c2f45f5a66017b2d387300d4d33640a820a7ccff71cbeb4fe5413e6bbf0d261a7dff01afafee7a82979d7a5644ab3afe6402541fe719bf500258813bbd55a721c0a4e5a6699a9f24fe07e572baacdf8cdea24fc79ccbf0979e9371ac23c6d68de36;
        in = 128'h8ea2b7ca516745bfeafc49904b496089;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        if (valid_data !== 1'b1) begin $display("FAIL V3: valid_data not asserted"); errors = errors + 1; end
        if (out !== 128'h00112233445566778899aabbccddeeff) begin $display("FAIL V3: wrong pt, got %h", out); errors = errors + 1; end

        @(posedge clk);
        #1;

        // ---- Vector 4: custom key, ct -> "Hello world!  :)" ----
        expanded_key = 1920'h5468697349735468654265737450617373776f72644943616e5468696e6b4f662aec5aec639f0e8406dd6bf7728d0a84332a082d57634b4c39372325575c6c4362bc40b701234e3307fe25c475732f40aea51d24f9c65668c0f1754d97ad190ef368eb3ff24ba50cf5b580c880c6af88631164e09ad732885a2647c5cd8b5ecbc630f482347b518ec1ced14641087ecee021976b7af6a5e320d0e226ed5bbcedef55a1d7db2ef0591ae0211f5be85fd1d9ba5855a34cfdb6839c1f906ec7a37d095f5e48d271ae11c8918f0e9379d0df050c28cba640d57d25dccaed4b1b6990e6a63efb34d790eafc461fe46f3fcf3b;
        in = 128'hea1044c3b1139b6cf71095be1071b90d;
        start_i = 1;
        @(posedge clk);
        #1; start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        if (valid_data !== 1'b1) begin $display("FAIL V4: valid_data not asserted"); errors = errors + 1; end
        if (out !== 128'h48656c6c6f20776f726c642120203a29) begin $display("FAIL V4: wrong pt, got %h", out); errors = errors + 1; end

        if (errors == 0)
            $display("[Decrypt Iterative TB] PASSED");
        else
            $display("[Decrypt Iterative TB] FAILED with %0d errors", errors);
        $finish;
    end

    always #1 clk = ~clk;
endmodule
