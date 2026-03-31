`timescale 1ns / 1ps

module EncryptIterativeTestBench;
    reg clk;
    reg rst;
    reg start_i;
    reg [0:127] in;
    reg [0:1919] expanded_key;

    wire [0:127] out;
    wire valid_data;

    Encrypt encrypt(
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .in(in),
        .expanded_key(expanded_key),
        .out(out),
        .valid_data(valid_data)
    );

    initial begin
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

        // ---- Vector 1: all-zero key, all-zero plaintext ----
        expanded_key = 1920'h000000000000000000000000000000000000000000000000000000000000000062636363626363636263636362636363aafbfbfbaafbfbfbaafbfbfbaafbfbfb6f6c6ccf0d0f0fac6f6c6ccf0d0f0fac7d8d8d6ad77676917d8d8d6ad77676915354edc15e5be26d31378ea23c38810e968a81c141fcf7503c717a3aeb070cab9eaa8f28c0f16d45f1c6e3e7cdfe62e92b312bdf6acddc8f56bca6b5bdbbaa1e6406fd52a4f79017553173f098cf11196dbba90b0776758451cad331ec71792fe7b0e89c4347788b16760b7b8eb91a6274ed0ba1739b7e252251ad14ce20d43b10f80a1753bf729c45c979e7cb706385;
        in = 128'h00000000000000000000000000000000;
        start_i = 1;
        @(posedge clk);
        start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        assert(valid_data == 1'b1) else $error("V1: valid_data not asserted");
        assert(out == 128'hdc95c078a2408989ad48a21492842087) else $error("V1: wrong ciphertext");

        @(posedge clk);

        // ---- Vector 2: NIST key 000102...1f, all-zero plaintext ----
        expanded_key = 1920'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1fa573c29fa176c498a97fce93a572c09c1651a8cd0244beda1a5da4c10640badeae87dff00ff11b68a68ed5fb03fc15676de1f1486fa54f9275f8eb5373b8518dc656827fc9a799176f294cec6cd5598b3de23a75524775e727bf9eb45407cf390bdc905fc27b0948ad5245a4c1871c2f45f5a66017b2d387300d4d33640a820a7ccff71cbeb4fe5413e6bbf0d261a7dff01afafee7a82979d7a5644ab3afe6402541fe719bf500258813bbd55a721c0a4e5a6699a9f24fe07e572baacdf8cdea24fc79ccbf0979e9371ac23c6d68de36;
        in = 128'h00000000000000000000000000000000;
        start_i = 1;
        @(posedge clk);
        start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        assert(valid_data == 1'b1) else $error("V2: valid_data not asserted");
        assert(out == 128'hf29000b62a499fd0a9f39a6add2e7780) else $error("V2: wrong ciphertext");

        @(posedge clk);

        // ---- Vector 3: NIST key, plaintext 00112233..eeff ----
        expanded_key = 1920'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1fa573c29fa176c498a97fce93a572c09c1651a8cd0244beda1a5da4c10640badeae87dff00ff11b68a68ed5fb03fc15676de1f1486fa54f9275f8eb5373b8518dc656827fc9a799176f294cec6cd5598b3de23a75524775e727bf9eb45407cf390bdc905fc27b0948ad5245a4c1871c2f45f5a66017b2d387300d4d33640a820a7ccff71cbeb4fe5413e6bbf0d261a7dff01afafee7a82979d7a5644ab3afe6402541fe719bf500258813bbd55a721c0a4e5a6699a9f24fe07e572baacdf8cdea24fc79ccbf0979e9371ac23c6d68de36;
        in = 128'h00112233445566778899aabbccddeeff;
        start_i = 1;
        @(posedge clk);
        start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        assert(valid_data == 1'b1) else $error("V3: valid_data not asserted");
        assert(out == 128'h8ea2b7ca516745bfeafc49904b496089) else $error("V3: wrong ciphertext");

        @(posedge clk);

        // ---- Vector 4: custom key, "Hello world!  :)" ----
        expanded_key = 1920'h5468697349735468654265737450617373776f72644943616e5468696e6b4f662aec5aec639f0e8406dd6bf7728d0a84332a082d57634b4c39372325575c6c4362bc40b701234e3307fe25c475732f40aea51d24f9c65668c0f1754d97ad190ef368eb3ff24ba50cf5b580c880c6af88631164e09ad732885a2647c5cd8b5ecbc630f482347b518ec1ced14641087ecee021976b7af6a5e320d0e226ed5bbcedef55a1d7db2ef0591ae0211f5be85fd1d9ba5855a34cfdb6839c1f906ec7a37d095f5e48d271ae11c8918f0e9379d0df050c28cba640d57d25dccaed4b1b6990e6a63efb34d790eafc461fe46f3fcf3b;
        in = "Hello world!  :)";
        start_i = 1;
        @(posedge clk);
        start_i = 0;
        repeat(14) @(posedge clk);
        #1;
        assert(valid_data == 1'b1) else $error("V4: valid_data not asserted");
        assert(out == 128'h8e00ecc38998b9806a9559f59054aaa6) else $error("V4: wrong ciphertext");

        $display("All iterative encrypt tests passed.");
        $finish;
    end

    always #1 clk = ~clk;
endmodule
