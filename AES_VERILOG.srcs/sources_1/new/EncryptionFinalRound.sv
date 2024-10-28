`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2024 09:57:59 PM
// Design Name: 
// Module Name: EncryptionFinalRound
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


module EncryptionFinalRound(
    input clk,
    input [0:127] in,
    input [0:1919] expanded_key,
    output reg [0:127] out
    );

wire [0:127] sub_bytes_output;
SubBytes sub_bytes_middle(.input_state(in),
                          .output_state(sub_bytes_output));
                          
wire [0:127] shift_rows_output;
ShiftRows shift_rows_middle(.input_state(sub_bytes_output),
                            .output_state(shift_rows_output));

wire [0:127]  add_round_key_out;                             
AddRoundKey add_round_key(.input_state(shift_rows_output),
                          .round_key(expanded_key[1792 +:128]),
                          .output_state(add_round_key_out));
always @(posedge clk) begin    
    if(!(^in === 1'bx) && !(^expanded_key[1792 +:128] === 1'bx)) begin   
        out <= add_round_key_out; //normal encryption rounds
    end
end
endmodule
