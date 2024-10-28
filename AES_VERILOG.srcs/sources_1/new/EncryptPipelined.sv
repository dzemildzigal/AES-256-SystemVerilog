`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2024 09:06:20 AM
// Design Name: 
// Module Name: EncryptPipelined
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


module EncryptPipelined(
    input clk,
    input rst,
    input [0:127] in,
    input [0:1919] expanded_key,
    output reg [0:127] out,
    output reg valid_data,
    
    
    output reg [0:127] ff_1_2_o,
    output reg [0:127] ff_2_3_o,
    output reg [0:127] ff_3_4_o,
    output reg [0:127] ff_4_5_o,
    output reg [0:127] ff_5_6_o,
    output reg [0:127] ff_6_7_o,
    output reg [0:127] ff_7_8_o,
    output reg [0:127] ff_8_9_o,
    output reg [0:127] ff_9_10_o,
    output reg [0:127] ff_10_11_o,
    output reg [0:127] ff_11_12_o,
    output reg [0:127] ff_12_13_o,
    output reg [0:127] ff_13_14_o
    );
integer i=0;
    
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
wire [0:127] final_out;
               
EncryptionInitialRound round1(.clk(clk),
                       .in(in),
                       .expanded_key(expanded_key),
                       .out(ff_1_2));
                       
EncryptionRound #(.i(2)) round2 (.clk(clk),
                                 .in(ff_1_2),
                                 .expanded_key(expanded_key),
                                 .out(ff_2_3));    
                                                                            
EncryptionRound #(.i(3)) round3(.clk(clk),
                                .in(ff_2_3),
                                .expanded_key(expanded_key),
                                .out(ff_3_4)); 
                       
EncryptionRound #(.i(4)) round4(.clk(clk),
                                .in(ff_3_4),
                                .expanded_key(expanded_key),
                                .out(ff_4_5));

EncryptionRound #(.i(5)) round5(.clk(clk),
                                .in(ff_4_5),
                                .expanded_key(expanded_key),
                                .out(ff_5_6)); 

EncryptionRound #(.i(6)) round6(.clk(clk),
                                .in(ff_5_6),
                                .expanded_key(expanded_key),
                                .out(ff_6_7));                        

EncryptionRound #(.i(7)) round7(.clk(clk),
                                .in(ff_6_7),
                                .expanded_key(expanded_key),
                                .out(ff_7_8));
                       
EncryptionRound #(.i(8)) round8(.clk(clk),
                                .in(ff_7_8),
                                .expanded_key(expanded_key),
                                .out(ff_8_9));
                       
EncryptionRound #(.i(9)) round9(.clk(clk),
                                .in(ff_8_9),
                                .expanded_key(expanded_key),
                                .out(ff_9_10));                        

EncryptionRound #(.i(10)) round10(.clk(clk),
                                  .in(ff_9_10),
                                  .expanded_key(expanded_key),
                                  .out(ff_10_11));    
                       
EncryptionRound #(.i(11)) round11(.clk(clk),
                                  .in(ff_10_11),
                                  .expanded_key(expanded_key),
                                  .out(ff_11_12));                                              
    
EncryptionRound #(.i(12)) round12(.clk(clk),
                                  .in(ff_11_12),
                                  .expanded_key(expanded_key),
                                  .out(ff_12_13));
                       
EncryptionRound #(.i(13)) round13(.clk(clk),
                                  .in(ff_12_13),
                                  .expanded_key(expanded_key),
                                  .out(ff_13_14));       
                                                              
EncryptionFinalRound round14(.clk(clk),
                             .in(ff_13_14),
                             .expanded_key(expanded_key),
                             .out(final_out));
                        
//Plain encryption block
    always @(posedge clk) begin
        if(rst) begin
            valid_data <= 1'b0;
        end
        else begin
                if(!(^in === 1'bx) && !(^expanded_key[i*128 +:128] === 1'bx) ) begin
                    if(i === 14) begin
                        valid_data <= 1'b1;
                        i <= 0;
                    end 
                    else begin
                        valid_data <= 1'b0;
                        i <= i + 1;
                    end 
                end
        end
            ff_1_2_o <= ff_1_2;
            ff_2_3_o <= ff_2_3;
            ff_3_4_o <= ff_3_4;
            ff_4_5_o <= ff_4_5;
            ff_5_6_o <= ff_5_6;
            ff_6_7_o <= ff_6_7;
            ff_7_8_o <= ff_7_8;
            ff_8_9_o <= ff_8_9;
            ff_9_10_o <= ff_9_10;
            ff_10_11_o <= ff_10_11;
            ff_11_12_o <= ff_11_12;
            ff_12_13_o <= ff_12_13;
            ff_13_14_o <= ff_13_14;
            out <= final_out;
    end
endmodule
