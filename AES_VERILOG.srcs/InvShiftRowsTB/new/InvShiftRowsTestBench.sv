`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module InvShiftRowsTestBench;
    reg clk;
    reg [0:127] input_state;
    wire [0:127] output_state;
    integer errors;

    InvShiftRows isr(.input_state(input_state),
                     .output_state(output_state));

    initial begin
        $display("[InvShiftRows TB] Starting...");
        errors = 0;
        clk = 0;
        @(posedge clk);

        input_state = 128'haa5ece06ee6e3c56dde68bac2621bebf;
        #1; if (output_state !== 128'haa218b56ee5ebeacdd6ecebf26e63c06) begin $display("FAIL V1"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hd1ed44fd1a0f3f2afa4ff27b7c332a69;
        #1; if (output_state !== 128'hd133f22a1aed2a7bfa0f44697c4f3ffd) begin $display("FAIL V2"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hcfb4dbedf4093808538502ac33de185c;
        #1; if (output_state !== 128'hcfde0208f4b418ac5309db5c338538ed) begin $display("FAIL V3"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h78e2acce741ed5425100c5e0e23b80c7;
        #1; if (output_state !== 128'h783bc54274e280e0511eacc7e200d5ce) begin $display("FAIL V4"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hd6f3d9dda6279bd1430d52a0e513f3fe;
        #1; if (output_state !== 128'hd61352d1a6f3f3a04327d9fee50d9bdd) begin $display("FAIL V5"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hbeb50aa6cff856126b0d6aff45c25dc4;
        #1; if (output_state !== 128'hbec26a12cfb55dff6bf80ac4450d56a6) begin $display("FAIL V6"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hf6e062ff507458f9be50497656ed654c;
        #1; if (output_state !== 128'hf6ed49f950e06576be74624c565058ff) begin $display("FAIL V7"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hd22f0c291ffe031a789d83b2ecc5364c;
        #1; if (output_state !== 128'hd2c5831a1f2f36b278fe0c4cec9d0329) begin $display("FAIL V8"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h2e6e7a2dafc6eef83a86ace7c25ba934;
        #1; if (output_state !== 128'h2e5bacf8af6ea9e73ac67a34c286ee2d) begin $display("FAIL V9"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h9cf0a62049fd59a399518984f26be178;
        #1; if (output_state !== 128'h9c6b89a349f0e18499fda678f2515920) begin $display("FAIL V10"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h88db34fb1f807678d3f833c2194a759e;
        #1; if (output_state !== 128'h884a33781fdb75c2d380349e19f876fb) begin $display("FAIL V11"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'had9c7e017e55ef25bc150fe01ccb6395;
        #1; if (output_state !== 128'hadcb0f257e9c63e0bc557e951c15ef01) begin $display("FAIL V12"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h84e1fd6b1a5c946fdf4938977cfbac23;
        #1; if (output_state !== 128'h84fb386f1ae1ac97df5cfd237c49946b) begin $display("FAIL V13"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h6353e08c0960e104cd70b751bacad0e7;
        #1; if (output_state !== 128'h63cab7040953d051cd60e0e7ba70e18c) begin $display("FAIL V14"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h9ced7cbef73139c0f0516bc520d72600;
        #1; if (output_state !== 128'h9cd76bc0f7ed26c5f0317c00205139be) begin $display("FAIL V15"); errors = errors + 1; end

        @(posedge clk);
        if (errors == 0)
            $display("[InvShiftRows TB] PASSED");
        else
            $display("[InvShiftRows TB] FAILED with %0d errors", errors);
        $finish;
    end

    always #1 clk = ~clk;
endmodule
