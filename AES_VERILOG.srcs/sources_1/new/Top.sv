`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Top-level AES-256 module.
// Wires KeyExpansion, EncryptPipelined, and DecryptPipelined together.
// Both pipelines share the same expanded key from KeyExpansion.
//
// Usage:
//   1. Assert rst for >= 1 cycle, then deassert.
//   2. Assert new_masterkey for 1 cycle with masterkey on the bus.
//   3. Wait for keys_ready == 4'd15 (all round keys computed).
//   4. Encrypt: set plaintext + assert start_i for 1 cycle.
//      After 15 cycles, ciphertext appears with ct_valid == 1.
//   5. Decrypt: set ciphertext_in + assert dec_start_i for 1 cycle.
//      After 15 cycles, decrypted appears with pt_valid == 1.

module Top(
    input  logic         clk,
    input  logic         rst,
    // Key interface
    input  logic         new_masterkey,
    input  logic [0:255] masterkey,
    output logic [3:0]   keys_ready,
    // Encrypt interface
    input  logic         start_i,
    input  logic [0:127] plaintext,
    output logic [0:127] ciphertext,
    output logic         ct_valid,
    // Decrypt interface
    input  logic         dec_start_i,
    input  logic [0:127] ciphertext_in,
    output logic [0:127] decrypted,
    output logic         pt_valid
    );

    // Internal: expanded key bus shared between KE and both pipelines
    logic [0:1919] expanded_key;

    KeyExpansion ke(
        .clk(clk),
        .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .w(expanded_key),
        .keys_ready(keys_ready)
    );

    EncryptPipelined ep(
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .in(plaintext),
        .expanded_key(expanded_key),
        .out(ciphertext),
        .valid_data(ct_valid)
    );

    DecryptPipelined dp(
        .clk(clk),
        .rst(rst),
        .start_i(dec_start_i),
        .in(ciphertext_in),
        .expanded_key(expanded_key),
        .out(decrypted),
        .valid_data(pt_valid)
    );

endmodule
