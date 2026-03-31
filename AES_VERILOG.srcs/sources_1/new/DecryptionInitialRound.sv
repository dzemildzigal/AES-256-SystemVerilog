`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Decryption initial round (pipelined stage 1):
// AddRoundKey(key14) -> InvShiftRows -> InvSubBytes -> InvMixColumns -> AddRoundKey(key13)
// Packs two key applications into one registered stage (mirrors EncryptionInitialRound).

module DecryptionInitialRound(
    input  logic        clk,
    input  logic        rst,
    input  logic [0:127] in,
    input  logic [0:1919] expanded_key,
    output logic [0:127] out
    );

wire [0:127] initial_add_key_out;
AddRoundKey initial_add_key(.input_state(in),
                            .round_key(expanded_key[1792 +:128]),
                            .output_state(initial_add_key_out));

wire [0:127] inv_shift_rows_output;
InvShiftRows inv_shift_rows(.input_state(initial_add_key_out),
                            .output_state(inv_shift_rows_output));

wire [0:127] inv_sub_bytes_output;
InvSubBytes inv_sub_bytes(.input_state(inv_shift_rows_output),
                          .output_state(inv_sub_bytes_output));

wire [0:127] add_round_key_out;
AddRoundKey add_round_key(.input_state(inv_sub_bytes_output),
                          .round_key(expanded_key[1664 +:128]),
                          .output_state(add_round_key_out));

wire [0:127] inv_mix_columns_output;
InvMixColumns inv_mix_columns(.input_state(add_round_key_out),
                              .output_state(inv_mix_columns_output));

always_ff @(posedge clk) begin
    if (rst)
        out <= '0;
    else
        out <= inv_mix_columns_output;
end
endmodule
