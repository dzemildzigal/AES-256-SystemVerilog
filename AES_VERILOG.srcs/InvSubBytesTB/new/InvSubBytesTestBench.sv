`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/05/2024 10:05:41 PM
// Design Name: 
// Module Name: InvSubBytesTestBench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module InvSubBytesTestBench;
    // inputs are -> reg, outputs are -> wire
    reg clk;
    reg rst;
    reg [0:127] input_state;
    wire [0:127] output_state;
    wire valid_data;
    
    InvSubBytes isb(.clk(clk),
                    .rst(rst),
                    .input_state(input_state),
                    .output_state(output_state),
                    .valid_data(valid_data)
                    );
    initial begin
        clk = 0;
        rst = 0;
        @(posedge clk);
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        @(posedge clk);
        
        input_state = 128'haa218b56ee5ebeacdd6ecebf26e63c06;
        @(posedge clk);
        assert (output_state == 128'h627bceb9999d5aaac945ecf423f56da5&& valid_data==1'b1);
        input_state = 128'hd133f22a1aed2a7bfa0f44697c4f3ffd;
        @(posedge clk);
        assert (output_state == 128'h516604954353950314fb86e401922521&& valid_data==1'b1);
        input_state = 128'hcfde0208f4b418ac5309db5c338538ed;
        @(posedge clk);
        assert (output_state == 128'h5f9c6abfbac634aa50409fa766677653&& valid_data==1'b1);
        input_state = 128'h783bc54274e280e0511eacc7e200d5ce;
        @(posedge clk);
        assert (output_state == 128'hc14907f6ca3b3aa070e9aa313b52b5ec&& valid_data==1'b1);
        input_state = 128'hd61352d1a6f3f3a04327d9fee50d9bdd;
        @(posedge clk);
        assert (output_state == 128'h4a824851c57e7e47643de50c2af3e8c9&& valid_data==1'b1);
        input_state = 128'hbec26a12cfb55dff6bf80ac4450d56a6;
        @(posedge clk);
        assert (output_state == 128'h5aa858395fd28d7d05e1a38868f3b9c5&& valid_data==1'b1);
        input_state = 128'hf6ed49f950e06576be74624c565058ff;
        @(posedge clk);
        assert (output_state == 128'hd653a4696ca0bc0f5acaab5db96c5e7d&& valid_data==1'b1);
        input_state = 128'hd2c5831a1f2f36b278fe0c4cec9d0329;
        @(posedge clk);
        assert (output_state == 128'h7f074143cb4e243ec10c815d8375d54c&& valid_data==1'b1);
        input_state = 128'h2e5bacf8af6ea9e73ac67a34c286ee2d;
        @(posedge clk);
        assert (output_state == 128'hc357aae11b45b7b0a2c7bd28a8dc99fa&& valid_data==1'b1);
        input_state = 128'h9c6b89a349f0e18499fda678f2515920;
        @(posedge clk);
        assert (output_state == 128'h1c05f271a417e04ff921c5c104701554&& valid_data==1'b1);
        input_state = 128'h884a33781fdb75c2d380349e19f876fb;
        @(posedge clk);
        assert (output_state == 128'h975c66c1cb9f3fa8a93a28df8ee10f63&& valid_data==1'b1);
        input_state = 128'hadcb0f257e9c63e0bc557e951c15ef01;
        @(posedge clk);
        assert (output_state == 128'h1859fbc28a1c00a078ed8aadc42f6109&& valid_data==1'b1);
        input_state = 128'h84fb386f1ae1ac97df5cfd237c49946b;
        @(posedge clk);
        assert (output_state == 128'h4f63760643e0aa85efa7213201a4e705&& valid_data==1'b1);
        input_state = 128'h63cab7040953d051cd60e0e7ba70e18c;
        @(posedge clk);
        assert (output_state == 128'h00102030405060708090a0b0c0d0e0f0&& valid_data==1'b1);
        input_state = 128'h0c4e8a8685b6765a0bc47a367f560b38;
        @(posedge clk);
        assert (output_state == 128'h81b6cfdc67790f469e88bd246bb99e76&& valid_data==1'b1);
        input_state = 128'h8b64e20d9766c3808c3d6f1d29bfbe4c;
        @(posedge clk);
        assert (output_state == 128'hce8c3bf385d3333af08b06de4cf45a5d&& valid_data==1'b1);
        input_state = 128'h910347accedf699000a3bcb888ac8238;
        @(posedge clk);
        assert (output_state == 128'hacd516aaecefe4965271789a97aa1176&& valid_data==1'b1);
        input_state = 128'h2915bce3e8dfb2f9a8d15f29a3bc0f02;
        @(posedge clk);
        assert (output_state == 128'h4c2f784dc8ef3e696f51844c7178fb6a&& valid_data==1'b1);
        input_state = 128'hdfae86c8a2ac6e0332618ad4b1852763;
        @(posedge clk);
        assert (output_state == 128'hefbedcb11aaa45d5a1d8cf1956673d00&& valid_data==1'b1);
        input_state = 128'h36c6a0d2d52a43ab217770dab4b19a6d;
        @(posedge clk);
        assert (output_state == 128'h24c7477fb595640e7b02d07ac65637b3&& valid_data==1'b1);
        input_state = 128'h22388471e9e2f0e3a9b0c5daff85f25e;
        @(posedge clk);
        assert (output_state == 128'h94764f2ceb3b174db7fc077a7d67049d&& valid_data==1'b1);
        input_state = 128'h73a3f5aaa3872146d37941b96ba80dc2;
        @(posedge clk);
        assert (output_state == 128'h8f71776271ea7b98a9aff8db056ff3a8&& valid_data==1'b1);
        input_state = 128'he8ac606badf00bf71e8e5b8572a420e7;
        @(posedge clk);
        assert (output_state == 128'hc8aa900518179e26e9e657671e1d54b0&& valid_data==1'b1);
        input_state = 128'h82a98330541f4d45e4d8f82806140aa0;
        @(posedge clk);
        assert (output_state == 128'h11b74108fdcb6568ae2de1eea59ba347&& valid_data==1'b1);
        input_state = 128'hfcedf49dcc55b6a6aae6197f976cd376;
        @(posedge clk);
        assert (output_state == 128'h5553ba7527ed79c562f58e6b85b8a90f&& valid_data==1'b1);
        input_state = 128'h39000227df6ca0e500aa1ccdd29d17bc;
        @(posedge clk);
        assert (output_state == 128'h5b526a3defb8472a5262c4807f758778&& valid_data==1'b1);
        input_state = 128'haeca75e2e25b918ce8f3b3dd0222bf68;
        @(posedge clk);
        assert (output_state == 128'hbe103f3b3b57acf0c87e4bc96a94f4f7&& valid_data==1'b1);
        input_state = 128'h9cd76bc0f7ed26c5f0317c00205139be;
        @(posedge clk);
        assert (output_state == 128'h1c0d051f26532307172e015254705b5a&& valid_data==1'b1);
        
        $stop;
        $finish;
    end
    
    //set up clock
    always #1 clk = ~clk;

endmodule
