`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AES-256 CTR Mode (NIST SP 800-38A §6.5).
//
// Encrypts {nonce, counter} through the pipelined AES-256 core to produce
// a keystream block, then XORs it with the input data.
//
// Because CTR is symmetric, the same operation encrypts AND decrypts:
//   ciphertext = plaintext  XOR AES(nonce || counter)
//   plaintext  = ciphertext XOR AES(nonce || counter)
//
// Latency:  16 clock cycles per block (15 pipeline + 1 output XOR register).
// Throughput: 1 block/cycle once pipeline is full (streaming with start_i
//             held high on consecutive cycles).
//
// Counter auto-increments after each block. Software can reload via
// counter_load / counter_init.
//
// Ports:
//   nonce[0:95]       — 96-bit nonce / IV (set once per message)
//   counter_init[0:31]— software-provided initial counter value
//   counter_load      — 1-cycle pulse to load counter_init
//   counter_val[0:31] — current counter value (readable)
//   data_in[0:127]    — plaintext (encrypt) or ciphertext (decrypt)
//   data_out[0:127]   — ciphertext (encrypt) or plaintext (decrypt)
//   out_valid         — asserted for 1 cycle when data_out is valid

module CtrMode(
    input  logic         clk,
    input  logic         rst,
    // Key interface
    input  logic         new_masterkey,
    input  logic [0:255] masterkey,
    output logic [3:0]   keys_ready,
    // Data interface
    input  logic         start_i,
    input  logic [0:95]  nonce,
    input  logic [0:127] data_in,
    output logic [0:127] data_out,
    output logic         out_valid,
    // Counter interface
    input  logic [0:31]  counter_init,
    input  logic         counter_load,
    output logic [0:31]  counter_val
);

    // ── Key Expansion ───────────────────────────────────────
    logic [0:1919] expanded_key;

    KeyExpansion ke(
        .clk(clk), .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .w(expanded_key),
        .keys_ready(keys_ready)
    );

    // ── Counter ─────────────────────────────────────────────
    // Auto-increments on each gated_start. Loadable from software.
    wire gated_start = start_i && (keys_ready == 4'd15);

    always_ff @(posedge clk) begin
        if (rst)
            counter_val <= '0;
        else if (counter_load)
            counter_val <= counter_init;
        else if (gated_start)
            counter_val <= counter_val + 32'd1;
    end

    // ── Encrypt Pipeline ────────────────────────────────────
    // Input: {nonce[96], counter[32]} = 128-bit CTR block
    wire [0:127] ctr_block = {nonce, counter_val};
    wire [0:127] keystream;
    wire         ks_valid;

    EncryptPipelined ep(
        .clk(clk), .rst(rst),
        .start_i(gated_start),
        .in(ctr_block),
        .expanded_key(expanded_key),
        .out(keystream),
        .valid_data(ks_valid)
    );

    // ── Data Delay Line ─────────────────────────────────────
    // EncryptPipelined latency = 15 cycles (14 stages + 1 output reg).
    // We add 1 more cycle for the XOR output register below, so
    // data_in must arrive at delay[DEPTH-1] when ks_valid is sampled.
    //
    // Cycle 0: gated_start=1, data_delay[0] <= data_in, pipeline accepts ctr_block
    // Cycle 15: ks_valid=1, keystream ready, data_delay[14] holds cycle-0 data_in
    // Cycle 15 posedge: data_out <= keystream ^ data_delay[14]; out_valid <= 1
    // Cycle 16: data_out and out_valid visible to downstream/AXI
    localparam DEPTH = 15;
    logic [0:127] data_delay [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < DEPTH; i++)
                data_delay[i] <= '0;
        end
        else begin
            data_delay[0] <= gated_start ? data_in : '0;
            for (int i = 1; i < DEPTH; i++)
                data_delay[i] <= data_delay[i-1];
        end
    end

    // ── Output XOR + Register ───────────────────────────────
    always_ff @(posedge clk) begin
        if (rst) begin
            data_out  <= '0;
            out_valid <= 1'b0;
        end
        else begin
            data_out  <= keystream ^ data_delay[DEPTH-1];
            out_valid <= ks_valid;
        end
    end

endmodule
