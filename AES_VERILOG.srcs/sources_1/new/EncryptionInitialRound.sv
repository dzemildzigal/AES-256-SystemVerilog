`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2024 10:22:59 PM
// Design Name: 
// Module Name: EncryptionInitialRound
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


module EncryptionInitialRound(
    input clk,
    input [0:127] in,
    input [0:1919] expanded_key,
    output reg [0:127] out
    );
    
wire [0:127] initial_add_key_out;
AddRoundKey initial_add_key(.input_state(in),
                            .round_key(expanded_key[0:127]),
                            .output_state(initial_add_key_out));

wire [0:127] sub_bytes_output;
SubBytes sub_bytes_middle(.input_state(initial_add_key_out),
                          .output_state(sub_bytes_output));
                          
wire [0:127] shift_rows_output;
ShiftRows shift_rows_middle(.input_state(sub_bytes_output),
                            .output_state(shift_rows_output));
                            
wire [0:127] mix_colmns_output;
MixColumns mix_columns_middle(.input_state(shift_rows_output),
                              .output_state(mix_colmns_output));   

wire [0:127]  add_round_key_out;                             
AddRoundKey add_round_key(.input_state(mix_colmns_output),
                          .round_key(expanded_key[128 +:128]),
                          .output_state(add_round_key_out));
                          
always @(posedge clk) begin 
    if(!(^in === 1'bx) && !(^expanded_key[0:127] === 1'bx) && !(^expanded_key[128 +:128] === 1'bx)) begin   
        out <= add_round_key_out; //normal encryption rounds
    end
end
endmodule
