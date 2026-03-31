`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AES-256 Encrypt-then-Decrypt roundtrip module (fully pipelined / streaming).
// Chains KeyExpansion -> EncryptPipelined -> DecryptPipelined.
// The encrypt ciphertext feeds directly into the decrypt input.
//
// Latency:  30 clock cycles from start_i to result_valid (initial fill).
// Throughput: 1 block per cycle once pipeline is full.
//
// A 30-deep delay line of saved plaintexts lets us compare each output
// to the exact plaintext that produced it, so "match" is valid even
// during continuous streaming.
//
// Outputs:
//   ct_out       — intermediate ciphertext (valid when ct_valid=1)
//   ct_valid     — asserted when ct_out is valid (15-cycle latency)
//   result       — decrypted plaintext (should match original input)
//   result_valid — asserted when result is valid (30-cycle latency)
//   match        — 1 if result == original plaintext for this block

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
    output logic [0:127] ct_out,
    output logic         ct_valid,
    output logic [0:127] result,
    output logic         result_valid,
    output logic         match
    );

    logic [0:1919] expanded_key;

    // Internal encrypt -> decrypt wires
    wire [0:127] enc_out;
    wire         enc_valid;
    wire [0:127] dec_out;
    wire         dec_valid;

    // Gate start until keys are ready (but no busy gate — streaming allowed)
    wire gated_start = start_i && (keys_ready == 4'd15);

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

    // Plaintext delay line: matches each result to its input.
    // Internal pipeline latency: 29 cycles from gated_start to dec_valid.
    // The output always_ff block adds 1 registered cycle, sampling at
    // cycle 30. The delay line must hold the correct plaintext at
    // pt_delay[DEPTH-1] when read at cycle 30's posedge (RHS sampling).
    // Plaintext enters pt_delay[0] at cycle 0; after 29 shifts it is at
    // pt_delay[29] at the END of cycle 29, readable at START of cycle 30.
    // Therefore DEPTH = 30.
    localparam DEPTH = 30;
    logic [0:127] pt_delay [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < DEPTH; i++)
                pt_delay[i] <= '0;
        end
        else begin
            pt_delay[0] <= gated_start ? plaintext : '0;
            for (int i = 1; i < DEPTH; i++)
                pt_delay[i] <= pt_delay[i-1];
        end
    end

    // Outputs — registered so that match compares pt_delay[DEPTH-1]
    // at the same posedge, using pre-NBA (RHS-sampled) values.
    // This adds 1 cycle of output latency: total = 30 cycles.
    always_ff @(posedge clk) begin
        if (rst) begin
            ct_out       <= '0;
            ct_valid     <= 1'b0;
            result       <= '0;
            result_valid <= 1'b0;
            match        <= 1'b0;
        end
        else begin
            ct_out       <= enc_out;
            ct_valid     <= enc_valid;
            result       <= dec_out;
            result_valid <= dec_valid;
            match        <= dec_valid && (dec_out == pt_delay[DEPTH-1]);
        end
    end

endmodule
