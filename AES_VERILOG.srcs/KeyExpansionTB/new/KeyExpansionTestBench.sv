`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2024 05:00:43 PM
// Design Name: 
// Module Name: KeyExpansionTestBench
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
module KeyExpansionTestBench;
    reg clk;
    reg rst;
    reg new_masterkey;
    reg [0:255] masterkey;
    wire [0:1919] w;
    wire valid_data;
    //wire [0:1] state;
    //wire [0:31] i_out;
    //wire [0:31] working_word_out;
    //wire [0:31] sub_word_out_out;
    //wire [0:31] rot_word_out_out;
    //wire [0:31] just_sub_word_out_out;
    
    KeyExpansion key_expansion(.clk(clk),
                               .rst(rst),
                               .new_masterkey(new_masterkey),
                               .masterkey(masterkey),
                               .w(w),
                               .valid_data(valid_data)
                               //.state(state),
                               //.i_out(i_out),
                               //.working_word_out(working_word_out),
                               //.sub_word_out_out(sub_word_out_out),
                               //.rot_word_out_out(rot_word_out_out),
                               //.just_sub_word_out_out(just_sub_word_out_out)
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
        new_masterkey = 1'b1;
        masterkey = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
                @(posedge clk);
        new_masterkey = 1'b0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        assert (w == 1920'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff49ba354118e6925afa51a8b5f2067fcdea8b09c1a93d194cdbe49846eb75d5b9ad59aecb85bf3c917fee94248de8ebe96b5a9328a2678a647983122292f6c79b3812c81addadf48ba24360af2fab8b46498c5bfc9bebd198e268c3ba709e0421468007bacb2df331696e939e46c518d80c814e20476a9fb8a5025c02d59c58239de1369676ccc5a71fa2563959674ee155886ca5d2e2f31d77e0af1fa27cf73c3749c47ab18501ddae2757e4f7401905acafaaae3e4d59b349adf6acebd10190dfe4890d1e6188d0b046df344706c631e);

    end
    always #1 clk = ~clk;
endmodule
