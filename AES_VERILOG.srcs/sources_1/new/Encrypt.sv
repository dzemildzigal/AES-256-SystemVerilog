`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: Encrypt
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


module Encrypt(
    input clk,
    input rst,
    input [0:127] in,
    input [0:1919] expanded_key,
    output reg [0:127] out,
    output reg valid_data
    );
    
reg [0:127] state;

reg [0:127] add_round_key_input_state;
reg [0:127] add_round_key_round_key; 
reg [0:127] add_round_key_output_state;   
AddRoundKey add_round_key(.input_state(add_round_key_input_state),
                          .round_key(add_round_key_round_key),
                          .output_state(add_round_key_output_state)
                          );
                          
reg [0:127] sub_bytes_input_state;
reg [0:127] sub_bytes_output_state;
SubBytes sub_bytes(.input_state(sub_bytes_input_state),
                   .output_state(sub_bytes_output_state)
                   );
                  
reg [0:127] shift_rows_input_state;
reg [0:127] shift_rows_output_state;
ShiftRows shift_rows(.input_state(shift_rows_input_state),
                     .output_state(shift_rows_output_state)
                     );
    
reg [0:127] mix_columns_input_state;
reg [0:127] mix_columns_output_state;
MixColumns mix_columns(.input_state(mix_columns_input_state),
                       .output_state(mix_columns_output_state)
                       );


integer i=0;
//Plain encryption block
    always @(posedge clk) begin
        if(rst) begin
            valid_data <= 1'b0;
        end
        else begin
            //working state
            if(!(^expanded_key[i<<7 +:128] === 1'bx)) begin 
                //if key expansion got to this point then work, otherwise wait
                if(i==0) begin
                    //initial add round key
                    state = in;
                    add_round_key_input_state = state;
                    add_round_key_round_key = expanded_key[0:127];
                    state = add_round_key_output_state;
                    i = i + 1;
                    valid_data = 1'b0;
                end
                else if(i>=1 && i <14)begin
                    //range 1 to Nr (Nr=14 for 256 AES)
                    sub_bytes_input_state = state;
                    shift_rows_input_state = sub_bytes_output_state;
                    mix_columns_input_state = shift_rows_output_state;
                    
                    add_round_key_input_state = mix_columns_output_state;
                    add_round_key_round_key = expanded_key[i*128 +:128];
                    state = add_round_key_output_state;
                    i = i + 1;
                    valid_data = 1'b0;
                end
                else if(i==14) begin
                    //i = 1414 and final steps
                    sub_bytes_input_state = state;
                    shift_rows_input_state = sub_bytes_output_state;
                    add_round_key_input_state = shift_rows_output_state;
                    add_round_key_round_key = expanded_key[i*128 +:128];
                    state = add_round_key_output_state;
                    valid_data = 1'b1;
                    i = 0;
                end
                out=state;
            end
        end
    end
endmodule
