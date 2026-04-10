`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// GF(2^128) multiplier for GHASH (AES-GCM) with a 2-cycle pipeline.
//
// Field polynomial:
//   x^128 + x^7 + x^2 + x + 1
//
// Bit ordering follows this repository's [0:N] convention:
//   bit 0   = MSB (leftmost bit)
//   bit 127 = LSB (rightmost bit)
//
// Handshake:
//   start_i = 1 for one cycle submits one multiply operation.
//   valid_o = 1 for one cycle exactly 2 cycles later.
//   Throughput = 1 operation/cycle.
//////////////////////////////////////////////////////////////////////////////////

module GFMult128(
    input  logic         clk,
    input  logic         rst,
    input  logic         start_i,
    input  logic [0:127] in_a,
    input  logic [0:127] in_b,
    output logic [0:127] out_o,
    output logic         valid_o
    );

    // GHASH reduction constant R = 11100001 || 0^120
    localparam logic [0:127] GHASH_R = 128'he1000000000000000000000000000000;

    logic [0:127] stage1_x;
    logic [0:127] stage1_z;
    logic [0:127] stage1_v;
    logic         stage1_valid;
    logic [0:127] stage2_res;
    logic         stage2_valid;

    // Right-shift by 1 in [0:127] big-endian indexing.
    function automatic logic [0:127] shift_right1_be;
        input logic [0:127] data;
        logic [0:127] tmp;
        integer j;
        begin
            tmp[0] = 1'b0;
            for (j = 1; j < 128; j = j + 1)
                tmp[j] = data[j-1];
            shift_right1_be = tmp;
        end
    endfunction

    // First 64 iterations of NIST SP 800-38D multiply algorithm (Algorithm 1).
    // Returns packed {z_after_64, v_after_64}.
    function automatic logic [0:255] gf_mul_ghash_first64;
        input logic [0:127] x;
        input logic [0:127] y;
        logic [0:127] z;
        logic [0:127] v;
        integer i;
        begin
            z = '0;
            v = y;

            for (i = 0; i < 64; i = i + 1) begin
                if (x[i])
                    z = z ^ v;

                if (v[127] == 1'b0)
                    v = shift_right1_be(v);
                else
                    v = shift_right1_be(v) ^ GHASH_R;
            end

            gf_mul_ghash_first64 = {z, v};
        end
    endfunction

    // Remaining 64 iterations (i=64..127), starting from {z_in, v_in}.
    function automatic logic [0:127] gf_mul_ghash_second64;
        input logic [0:127] x;
        input logic [0:127] z_in;
        input logic [0:127] v_in;
        logic [0:127] z;
        logic [0:127] v;
        integer i;
        begin
            z = z_in;
            v = v_in;

            for (i = 64; i < 128; i = i + 1) begin
                if (x[i])
                    z = z ^ v;

                if (v[127] == 1'b0)
                    v = shift_right1_be(v);
                else
                    v = shift_right1_be(v) ^ GHASH_R;
            end

            gf_mul_ghash_second64 = z;
        end
    endfunction

    // 2-stage pipeline:
    //   Stage 1: first 64 GF iterations, register intermediate {x,z,v}
    //   Stage 2: second 64 GF iterations, register final product
    always_ff @(posedge clk) begin
        if (rst) begin
            stage1_x     <= '0;
            stage1_z     <= '0;
            stage1_v     <= '0;
            stage1_valid <= 1'b0;
            stage2_res   <= '0;
            stage2_valid <= 1'b0;
        end
        else begin
            stage1_x     <= in_a;
            {stage1_z, stage1_v} <= gf_mul_ghash_first64(in_a, in_b);
            stage1_valid <= start_i;

            stage2_res   <= gf_mul_ghash_second64(stage1_x, stage1_z, stage1_v);
            stage2_valid <= stage1_valid;
        end
    end

    assign out_o   = stage2_res;
    assign valid_o = stage2_valid;

endmodule
