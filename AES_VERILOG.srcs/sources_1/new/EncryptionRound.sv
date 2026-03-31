`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module EncryptionRound
    #(parameter i=0)
    (
    input  logic        clk,
    input  logic        rst,
    input  logic [0:127] in,
    input  logic [0:1919] expanded_key,
    output logic [0:127] out
    );

wire [0:127] sub_bytes_output;
SubBytes sub_bytes_middle(.input_state(in),
                          .output_state(sub_bytes_output));

wire [0:127] shift_rows_output;
ShiftRows shift_rows_middle(.input_state(sub_bytes_output),
                            .output_state(shift_rows_output));

wire [0:127] mix_columns_output;
MixColumns mix_columns_middle(.input_state(shift_rows_output),
                              .output_state(mix_columns_output));

wire [0:127] add_round_key_out;
AddRoundKey add_round_key(.input_state(mix_columns_output),
                          .round_key(expanded_key[i*128 +:128]),
                          .output_state(add_round_key_out));

always_ff @(posedge clk) begin
    if (rst)
        out <= '0;
    else
        out <= add_round_key_out;
end
endmodule
