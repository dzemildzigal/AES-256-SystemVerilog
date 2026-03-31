`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module InvSubBytesTestBench;
    reg clk;
    reg [0:127] input_state;
    wire [0:127] output_state;
    integer errors;

    InvSubBytes isb(.input_state(input_state),
                    .output_state(output_state));

    initial begin
        $display("[InvSubBytes TB] Starting...");
        errors = 0;
        clk = 0;
        @(posedge clk);

        input_state = 128'haa218b56ee5ebeacdd6ecebf26e63c06;
        #1; if (output_state !== 128'h627bceb9999d5aaac945ecf423f56da5) begin $display("FAIL V1"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hd133f22a1aed2a7bfa0f44697c4f3ffd;
        #1; if (output_state !== 128'h516604954353950314fb86e401922521) begin $display("FAIL V2"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hcfde0208f4b418ac5309db5c338538ed;
        #1; if (output_state !== 128'h5f9c6abfbac634aa50409fa766677653) begin $display("FAIL V3"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h783bc54274e280e0511eacc7e200d5ce;
        #1; if (output_state !== 128'hc14907f6ca3b3aa070e9aa313b52b5ec) begin $display("FAIL V4"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hd61352d1a6f3f3a04327d9fee50d9bdd;
        #1; if (output_state !== 128'h4a824851c57e7e47643de50c2af3e8c9) begin $display("FAIL V5"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hbec26a12cfb55dff6bf80ac4450d56a6;
        #1; if (output_state !== 128'h5aa858395fd28d7d05e1a38868f3b9c5) begin $display("FAIL V6"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hf6ed49f950e06576be74624c565058ff;
        #1; if (output_state !== 128'hd653a4696ca0bc0f5acaab5db96c5e7d) begin $display("FAIL V7"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hd2c5831a1f2f36b278fe0c4cec9d0329;
        #1; if (output_state !== 128'h7f074143cb4e243ec10c815d8375d54c) begin $display("FAIL V8"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h2e5bacf8af6ea9e73ac67a34c286ee2d;
        #1; if (output_state !== 128'hc357aae11b45b7b0a2c7bd28a8dc99fa) begin $display("FAIL V9"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h9c6b89a349f0e18499fda678f2515920;
        #1; if (output_state !== 128'h1c05f271a417e04ff921c5c104701554) begin $display("FAIL V10"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h884a33781fdb75c2d380349e19f876fb;
        #1; if (output_state !== 128'h975c66c1cb9f3fa8a93a28df8ee10f63) begin $display("FAIL V11"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hadcb0f257e9c63e0bc557e951c15ef01;
        #1; if (output_state !== 128'h1859fbc28a1c00a078ed8aadc42f6109) begin $display("FAIL V12"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h84fb386f1ae1ac97df5cfd237c49946b;
        #1; if (output_state !== 128'h4f63760643e0aa85efa7213201a4e705) begin $display("FAIL V13"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h63cab7040953d051cd60e0e7ba70e18c;
        #1; if (output_state !== 128'h00102030405060708090a0b0c0d0e0f0) begin $display("FAIL V14"); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h9cd76bc0f7ed26c5f0317c00205139be;
        #1; if (output_state !== 128'h1c0d051f26532307172e015254705b5a) begin $display("FAIL V15"); errors = errors + 1; end

        @(posedge clk);
        if (errors == 0)
            $display("[InvSubBytes TB] PASSED");
        else
            $display("[InvSubBytes TB] FAILED with %0d errors", errors);
        $finish;
    end

    always #1 clk = ~clk;
endmodule
