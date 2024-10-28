`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2024 09:18:00 PM
// Design Name: 
// Module Name: EncryptTestBench
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
module EncryptTestBench;
    reg clk;
    reg rst;
    reg [0:127] in;
    reg [0:1919] expanded_key;
    
    wire [0:127] out;
    wire valid_data;
    wire [0:127] ff_1_2;
    wire [0:127] ff_2_3;
    wire [0:127] ff_3_4;
    wire [0:127] ff_4_5;
    wire [0:127] ff_5_6;
    wire [0:127] ff_6_7;
    wire [0:127] ff_7_8;
    wire [0:127] ff_8_9;
    wire [0:127] ff_9_10;
    wire [0:127] ff_10_11;
    wire [0:127] ff_11_12;
    wire [0:127] ff_12_13;
    wire [0:127] ff_13_14;
        
EncryptPipelined encrypt(.clk(clk),
                .rst(rst),
                .in(in),
                .expanded_key(expanded_key),
                .out(out),
                .valid_data(valid_data),
                .ff_1_2_o(ff_1_2),
                .ff_2_3_o(ff_2_3),
                .ff_3_4_o(ff_3_4),
                .ff_4_5_o(ff_4_5),
                .ff_5_6_o(ff_5_6),
                .ff_6_7_o(ff_6_7),
                .ff_7_8_o(ff_7_8),
                .ff_8_9_o(ff_8_9),
                .ff_9_10_o(ff_9_10),
                .ff_10_11_o(ff_10_11),
                .ff_11_12_o(ff_11_12),
                .ff_12_13_o(ff_12_13),
                .ff_13_14_o(ff_13_14)
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
        //expanded key for masterkey all 0's
        expanded_key = 1920'h000000000000000000000000000000000000000000000000000000000000000062636363626363636263636362636363aafbfbfbaafbfbfbaafbfbfbaafbfbfb6f6c6ccf0d0f0fac6f6c6ccf0d0f0fac7d8d8d6ad77676917d8d8d6ad77676915354edc15e5be26d31378ea23c38810e968a81c141fcf7503c717a3aeb070cab9eaa8f28c0f16d45f1c6e3e7cdfe62e92b312bdf6acddc8f56bca6b5bdbbaa1e6406fd52a4f79017553173f098cf11196dbba90b0776758451cad331ec71792fe7b0e89c4347788b16760b7b8eb91a6274ed0ba1739b7e252251ad14ce20d43b10f80a1753bf729c45c979e7cb706385;
        //message all 0's
        in = 128'h00000000000000000000000000000000;
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
        assert(valid_data == 1'b1);
        assert(out == 128'hdc95c078a2408989ad48a21492842087);
        
end
    always #1 clk = ~clk;        
endmodule
