`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Top-level AES-256 encryption module.
// Wires KeyExpansion and EncryptPipelined together.
//
// Usage:
//   1. Assert rst for >= 1 cycle, then deassert.
//   2. Assert new_masterkey for 1 cycle with masterkey on the bus.
//   3. Wait for keys_ready == 4'd15 (all round keys computed).
//   4. For each plaintext block: set plaintext, assert start_i for 1 cycle.
//      - Keep expanded key stable while blocks are in flight.
//   5. After 15 cycles, ciphertext appears on ct with ct_valid == 1.
//      In streaming mode, one ciphertext per cycle after the pipeline fills.

module Top(
    input  logic         clk,
    input  logic         rst,
    // Key interface
    input  logic         new_masterkey,
    input  logic [0:255] masterkey,
    output logic [3:0]   keys_ready,
    // Data interface
    input  logic         start_i,
    input  logic [0:127] plaintext,
    output logic [0:127] ciphertext,
    output logic         ct_valid
    );

    // Internal: expanded key bus shared between KE and pipeline
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

endmodule
