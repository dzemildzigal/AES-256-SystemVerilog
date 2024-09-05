`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/05/2024 11:07:20 PM
// Design Name: 
// Module Name: InvShiftRowsTestBench
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


module InvShiftRowsTestBench;
    reg clk;
    reg rst;
    reg [0:127] input_state;
    wire [0:127] output_state;
    wire valid_data;
    
    InvShiftRows isr(.clk(clk),
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
        
        input_state = 128'haa5ece06ee6e3c56dde68bac2621bebf;
        @(posedge clk);
        assert (output_state == 128'haa218b56ee5ebeacdd6ecebf26e63c06&& valid_data==1'b1);
        input_state = 128'hd1ed44fd1a0f3f2afa4ff27b7c332a69;
        @(posedge clk);
        assert (output_state == 128'hd133f22a1aed2a7bfa0f44697c4f3ffd&& valid_data==1'b1);
        input_state = 128'hcfb4dbedf4093808538502ac33de185c;
        @(posedge clk);
        assert (output_state == 128'hcfde0208f4b418ac5309db5c338538ed&& valid_data==1'b1);
        input_state = 128'h78e2acce741ed5425100c5e0e23b80c7;
        @(posedge clk);
        assert (output_state == 128'h783bc54274e280e0511eacc7e200d5ce&& valid_data==1'b1);
        input_state = 128'hd6f3d9dda6279bd1430d52a0e513f3fe;
        @(posedge clk);
        assert (output_state == 128'hd61352d1a6f3f3a04327d9fee50d9bdd&& valid_data==1'b1);
        input_state = 128'hbeb50aa6cff856126b0d6aff45c25dc4;
        @(posedge clk);
        assert (output_state == 128'hbec26a12cfb55dff6bf80ac4450d56a6&& valid_data==1'b1);
        input_state = 128'hf6e062ff507458f9be50497656ed654c;
        @(posedge clk);
        assert (output_state == 128'hf6ed49f950e06576be74624c565058ff&& valid_data==1'b1);
        input_state = 128'hd22f0c291ffe031a789d83b2ecc5364c;
        @(posedge clk);
        assert (output_state == 128'hd2c5831a1f2f36b278fe0c4cec9d0329&& valid_data==1'b1);
        input_state = 128'h2e6e7a2dafc6eef83a86ace7c25ba934;
        @(posedge clk);
        assert (output_state == 128'h2e5bacf8af6ea9e73ac67a34c286ee2d&& valid_data==1'b1);
        input_state = 128'h9cf0a62049fd59a399518984f26be178;
        @(posedge clk);
        assert (output_state == 128'h9c6b89a349f0e18499fda678f2515920&& valid_data==1'b1);
        input_state = 128'h88db34fb1f807678d3f833c2194a759e;
        @(posedge clk);
        assert (output_state == 128'h884a33781fdb75c2d380349e19f876fb&& valid_data==1'b1);
        input_state = 128'had9c7e017e55ef25bc150fe01ccb6395;
        @(posedge clk);
        assert (output_state == 128'hadcb0f257e9c63e0bc557e951c15ef01&& valid_data==1'b1);
        input_state = 128'h84e1fd6b1a5c946fdf4938977cfbac23;
        @(posedge clk);
        assert (output_state == 128'h84fb386f1ae1ac97df5cfd237c49946b&& valid_data==1'b1);
        input_state = 128'h6353e08c0960e104cd70b751bacad0e7;
        @(posedge clk);
        assert (output_state == 128'h63cab7040953d051cd60e0e7ba70e18c&& valid_data==1'b1);
        input_state = 128'h0cb67a3885c40b860b568a5a7f4e7636;
        @(posedge clk);
        assert (output_state == 128'h0c4e8a8685b6765a0bc47a367f560b38&& valid_data==1'b1);
        input_state = 128'h8b666f4c973dbe0d8cbfe2802964c31d;
        @(posedge clk);
        assert (output_state == 128'h8b64e20d9766c3808c3d6f1d29bfbe4c&& valid_data==1'b1);
        input_state = 128'h91dfbc38cea382ac00ac4790880369b8;
        @(posedge clk);
        assert (output_state == 128'h910347accedf699000a3bcb888ac8238&& valid_data==1'b1);
        input_state = 128'h29df5f02e8d10fe3a8bcbcf9a315b229;
        @(posedge clk);
        assert (output_state == 128'h2915bce3e8dfb2f9a8d15f29a3bc0f02&& valid_data==1'b1);
        input_state = 128'hdfac8a63a26127c832858603b1ae6ed4;
        @(posedge clk);
        assert (output_state == 128'hdfae86c8a2ac6e0332618ad4b1852763&& valid_data==1'b1);
        input_state = 128'h362a706dd5779ad221b1a0abb4c643da;
        @(posedge clk);
        assert (output_state == 128'h36c6a0d2d52a43ab217770dab4b19a6d&& valid_data==1'b1);
        input_state = 128'h22e2c55ee9b0f271a98584e3ff38f0da;
        @(posedge clk);
        assert (output_state == 128'h22388471e9e2f0e3a9b0c5daff85f25e&& valid_data==1'b1);
        input_state = 128'h738741c2a3790daad3a8f5466ba321b9;
        @(posedge clk);
        assert (output_state == 128'h73a3f5aaa3872146d37941b96ba80dc2&& valid_data==1'b1);
        input_state = 128'he8f05be7ad8e206b1ea460f772ac0b85;
        @(posedge clk);
        assert (output_state == 128'he8ac606badf00bf71e8e5b8572a420e7&& valid_data==1'b1);
        input_state = 128'h821ff8a054d80a30e414834506a94d28;
        @(posedge clk);
        assert (output_state == 128'h82a98330541f4d45e4d8f82806140aa0&& valid_data==1'b1);
        input_state = 128'hfc551976cce6d39daa6cf4a697edb67f;
        @(posedge clk);
        assert (output_state == 128'hfcedf49dcc55b6a6aae6197f976cd376&& valid_data==1'b1);
        input_state = 128'h396c1cbcdfaa1727009d02e5d200a0cd;
        @(posedge clk);
        assert (output_state == 128'h39000227df6ca0e500aa1ccdd29d17bc&& valid_data==1'b1);
        input_state = 128'hae5bb368e2f3bfe2e822758c02ca91dd;
        @(posedge clk);
        assert (output_state == 128'haeca75e2e25b918ce8f3b3dd0222bf68&& valid_data==1'b1);
        input_state = 128'h9ced7cbef73139c0f0516bc520d72600;
        @(posedge clk);
        assert (output_state == 128'h9cd76bc0f7ed26c5f0317c00205139be&& valid_data==1'b1);
    end
    // set up clk
    always #1 clk = ~clk;
endmodule
