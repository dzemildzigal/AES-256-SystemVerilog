`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Decryption final round (pipelined last stage):
// InvShiftRows -> InvSubBytes -> AddRoundKey(key0)
// No InvMixColumns in the final round.

module DecryptionFinalRound(
    input  logic        clk,
    input  logic        rst,
    input  logic [0:127] in,
    input  logic [0:1919] expanded_key,
    output logic [0:127] out
    );

wire [0:127] inv_shift_rows_output;
InvShiftRows inv_shift_rows(.input_state(in),
                            .output_state(inv_shift_rows_output));

wire [0:127] inv_sub_bytes_output;
InvSubBytes inv_sub_bytes(.input_state(inv_shift_rows_output),
                          .output_state(inv_sub_bytes_output));

wire [0:127] add_round_key_out;
AddRoundKey add_round_key(.input_state(inv_sub_bytes_output),
                          .round_key(expanded_key[0 +:128]),
                          .output_state(add_round_key_out));

always_ff @(posedge clk) begin
    if (rst)
        out <= '0;
    else
        out <= add_round_key_out;
end
endmodule
