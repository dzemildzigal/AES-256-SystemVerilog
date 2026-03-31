`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AES-256 Encrypt-then-Decrypt roundtrip module.
// Chains KeyExpansion -> EncryptPipelined -> DecryptPipelined.
// The encrypt ciphertext feeds directly into the decrypt input.
// Total latency: 30 clock cycles from start_i to result_valid.
//
// Outputs:
//   ct_latched   — intermediate ciphertext (latched when encrypt finishes)
//   result       — decrypted plaintext (should match original input)
//   result_valid — asserted for 1+ cycles when result is ready
//   match        — 1 if result == original plaintext
//   busy         — 1 while a roundtrip is in progress

module TopRoundtrip(
    input  logic         clk,
    input  logic         rst,
    // Key interface
    input  logic         new_masterkey,
    input  logic [0:255] masterkey,
    output logic [3:0]   keys_ready,
    // Data interface
    input  logic         start_i,
    input  logic [0:127] plaintext,
    // Outputs
    output logic [0:127] ct_latched,
    output logic [0:127] result,
    output logic         busy,
    output logic         result_valid,
    output logic         match
    );

    logic [0:1919] expanded_key;
    logic [0:127]  pt_saved;

    // Internal encrypt -> decrypt wires
    wire [0:127] enc_out;
    wire         enc_valid;
    wire [0:127] dec_out;
    wire         dec_valid;

    // Only accept new data when idle and keys are fully expanded
    wire gated_start = start_i && !busy && (keys_ready == 4'd15);

    KeyExpansion ke(
        .clk(clk), .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .w(expanded_key),
        .keys_ready(keys_ready)
    );

    EncryptPipelined ep(
        .clk(clk), .rst(rst),
        .start_i(gated_start),
        .in(plaintext),
        .expanded_key(expanded_key),
        .out(enc_out),
        .valid_data(enc_valid)
    );

    // Chain: encrypt output -> decrypt input
    DecryptPipelined dp(
        .clk(clk), .rst(rst),
        .start_i(enc_valid),
        .in(enc_out),
        .expanded_key(expanded_key),
        .out(dec_out),
        .valid_data(dec_valid)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            pt_saved     <= '0;
            ct_latched   <= '0;
            result       <= '0;
            busy         <= 1'b0;
            result_valid <= 1'b0;
            match        <= 1'b0;
        end
        else begin
            if (gated_start) begin
                pt_saved     <= plaintext;
                busy         <= 1'b1;
                result_valid <= 1'b0;
                match        <= 1'b0;
            end
            if (enc_valid)
                ct_latched <= enc_out;
            if (dec_valid) begin
                result       <= dec_out;
                result_valid <= 1'b1;
                match        <= (dec_out == pt_saved);
                busy         <= 1'b0;
            end
        end
    end
endmodule
