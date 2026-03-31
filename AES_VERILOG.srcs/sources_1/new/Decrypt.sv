`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Iterative AES-256 Decrypt: 15 clock cycles per block.
// Round 0: AddRoundKey(key14)
// Rounds 1-13: InvShiftRows -> InvSubBytes -> AddRoundKey(key_{14-i}) -> InvMixColumns
// Round 14: InvShiftRows -> InvSubBytes -> AddRoundKey(key0)

module Decrypt(
    input  logic        clk,
    input  logic        rst,
    input  logic        start_i,
    input  logic [0:127] in,
    input  logic [0:1919] expanded_key,
    output logic [0:127] out,
    output logic        valid_data
    );

    logic [0:127] state;
    logic [3:0]   round_i;
    logic         running;

    // Combinational InvShiftRows -> InvSubBytes chain
    wire [0:127] inv_shift_rows_out;
    InvShiftRows inv_shift_rows(
        .input_state(state),
        .output_state(inv_shift_rows_out)
    );

    wire [0:127] inv_sub_bytes_out;
    InvSubBytes inv_sub_bytes(
        .input_state(inv_shift_rows_out),
        .output_state(inv_sub_bytes_out)
    );

    // Combinational mux for AddRoundKey inputs
    logic [0:127] ark_in;
    logic [0:127] ark_key;
    wire  [0:127] ark_out;

    always_comb begin
        if (!running || round_i == 4'd0) begin
            ark_in = in;
        end
        else begin
            ark_in = inv_sub_bytes_out;
        end
        // Key index counts down: 14, 13, 12, ..., 0
        ark_key = expanded_key[(4'd14 - round_i) * 128 +:128];
    end

    AddRoundKey add_round_key(
        .input_state(ark_in),
        .round_key(ark_key),
        .output_state(ark_out)
    );

    // Combinational InvMixColumns (applied after AddRoundKey in middle rounds)
    wire [0:127] inv_mix_columns_out;
    InvMixColumns inv_mix_columns(
        .input_state(ark_out),
        .output_state(inv_mix_columns_out)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= '0;
            round_i    <= 4'd0;
            running    <= 1'b0;
            valid_data <= 1'b0;
            out        <= '0;
        end
        else if (start_i && !running) begin
            // Round 0: just AddRoundKey(key14)
            state      <= ark_out;
            round_i    <= 4'd1;
            running    <= 1'b1;
            valid_data <= 1'b0;
        end
        else if (running) begin
            if (round_i == 4'd14) begin
                // Final round: no InvMixColumns
                out        <= ark_out;
                state      <= ark_out;
                valid_data <= 1'b1;
                round_i    <= 4'd0;
                running    <= 1'b0;
            end
            else begin
                // Middle round: InvMixColumns after AddRoundKey
                state      <= inv_mix_columns_out;
                round_i    <= round_i + 4'd1;
                valid_data <= 1'b0;
            end
        end
        else begin
            valid_data <= 1'b0;
        end
    end
endmodule
