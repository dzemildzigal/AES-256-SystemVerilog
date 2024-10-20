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
wire [0:127] add_round_key_output_state;   
AddRoundKey add_round_key(.input_state(add_round_key_input_state),
                          .round_key(add_round_key_round_key),
                          .output_state(add_round_key_output_state)
                          );

wire [0:127] sub_bytes_middle_output;
SubBytes sub_bytes_middle(.input_state(state),
                          .output_state(sub_bytes_middle_output));
wire [0:127] shift_rows_middle_output;
ShiftRows shift_rows_middle(.input_state(sub_bytes_middle_output),
                            .output_state(shift_rows_middle_output));
wire [0:127] mix_colmns_middle_output;
MixColumns mix_columns_middle(.input_state(shift_rows_middle_output),
                              .output_state(mix_colmns_middle_output));

integer i=0;
integer read_data=0;
//Plain encryption block
    always @(posedge clk) begin
        if(rst) begin
            valid_data <= 1'b0;
        end
        else begin
            //working state, since evaluation is not instant but in next time segment we need to divide this.
            if(!(^expanded_key[i<<7 +:128] === 1'bx) /*&& !(^state === 1'bx)*/) begin 
                //if key expansion got to this point then work, otherwise wait
                if(read_data == 0) begin
                    if(i==0) begin
                        //initial add round key
                        state = in;
                        add_round_key_input_state = state;
                        add_round_key_round_key = expanded_key[0:127];
                        valid_data = 1'b0;
                        i = i + 1;
                        
                    end
                    else if(i>=1 && i <14)begin
                        //range 1 to Nr (Nr=14 for 256 AES)
                        add_round_key_input_state = mix_colmns_middle_output;
                        add_round_key_round_key = expanded_key[i*128 +:128];
                        valid_data = 1'b0;
                        i = i + 1;
                    end
                    else if(i==14) begin
                        //i = 14 and final steps
                        add_round_key_input_state = shift_rows_middle_output;
                        add_round_key_round_key = expanded_key[i*128 +:128];
                        i = 0;
                    end
                    read_data = 1;
                end
                else if (read_data == 1) begin
                    state = add_round_key_output_state;
                    out   = state;
                    if (i==0) begin
                        valid_data = 1'b1;
                    end
                    read_data = 0;
                end
            end
        end
    end
endmodule
