`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// InvMixColumns testbench: feed MixColumns outputs, verify original inputs recovered.

module InvMixColumnsTestBench;
    reg clk;
    reg [0:127] input_state;
    wire [0:127] output_state;
    integer errors;

    InvMixColumns inv_mix_columns(
        .input_state(input_state),
        .output_state(output_state)
    );

    initial begin
        $display("[InvMixColumns TB] Starting...");
        errors = 0;
        clk = 0;
        @(posedge clk);

        // Identical columns (fixed point)
        input_state = 128'h63636363636363636363636363636363;
        #1;
        if (output_state !== 128'h63636363636363636363636363636363) begin $display("FAIL V1: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hfbfbfbfbfbfbfbfbfbfbfbfbfbfbfbfb;
        #1;
        if (output_state !== 128'hfbfbfbfbfbfbfbfbfbfbfbfbfbfbfbfb) begin $display("FAIL V2: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h0deeeea50deeeea50deeeea50deeeea5;
        #1;
        if (output_state !== 128'hee464646ee464646ee464646ee464646) begin $display("FAIL V3: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h525d5f54525d5f54525d5f54525d5f54;
        #1;
        if (output_state !== 128'h5c5959585c5959585c5959585c595958) begin $display("FAIL V4: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hc20020746547d63bc45dcd09b4f5751a;
        #1;
        if (output_state !== 128'hb2c16782367800814aaef9405a3ac789) begin $display("FAIL V5: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h04c7c0a89cc0542c4f612d8639ec0e54;
        #1;
        if (output_state !== 128'h20eaa9c83671b6d54189327fcf7efdc3) begin $display("FAIL V6: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'hc8d1fc6bedcffa537a49644ddc1e8d31;
        #1;
        if (output_state !== 128'hb8c78b7a4a5c50cdaec984f9bf3c12ef) begin $display("FAIL V7: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h8b85134b5e02fe1260e9fa8c4b7538be;
        #1;
        if (output_state !== 128'h1177251517e6cc8d71060e86efe1f741) begin $display("FAIL V8: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h6fa6888388cf7a0073768fab6c0f9ff9;
        #1;
        if (output_state !== 128'hdfe6a75c2d61a5d496f4286b66ec9f10) begin $display("FAIL V9: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'ha8f3b47203f446ed912d601eb8bc56f5;
        #1;
        if (output_state !== 128'h77564af673658ec493f3fd5fcda476b8) begin $display("FAIL V10: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h5357948e58281a5bea2cbd7edbb1b73d;
        #1;
        if (output_state !== 128'h846d7f8809392928176b4a33051ab24d) begin $display("FAIL V11: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        input_state = 128'h6a6a5c452c6d3351b0d95d61279c215c;
        #1;
        if (output_state !== 128'h636b6776f201ab7b30d777c5fe7c6f2b) begin $display("FAIL V12: got %h", output_state); errors = errors + 1; end

        @(posedge clk);
        if (errors == 0)
            $display("[InvMixColumns TB] PASSED");
        else
            $display("[InvMixColumns TB] FAILED with %0d errors", errors);
        $finish;
    end

    always #1 clk = ~clk;
endmodule
