`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// GF(2^128) multiplier for GHASH (AES-GCM) with 1-cycle latency.
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
//   valid_o = 1 for one cycle exactly 1 cycle later.
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

    logic [0:127] result_reg;
    logic         valid_reg;

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

    // Full 128-iteration GHASH multiply (NIST SP 800-38D Algorithm 1).
    // Purely combinational – synthesis collapses this into parallel XOR trees.
    function automatic logic [0:127] gf_mul_ghash;
        input logic [0:127] x;
        input logic [0:127] y;
        logic [0:127] z;
        logic [0:127] v;
        integer i;
        begin
            z = '0;
            v = y;

            for (i = 0; i < 128; i = i + 1) begin
                if (x[i])
                    z = z ^ v;

                if (v[127] == 1'b0)
                    v = shift_right1_be(v);
                else
                    v = shift_right1_be(v) ^ GHASH_R;
            end

            gf_mul_ghash = z;
        end
    endfunction

    // 1-cycle pipeline: full multiply is combinational, result registered.
    always_ff @(posedge clk) begin
        if (rst) begin
            result_reg <= '0;
            valid_reg  <= 1'b0;
        end
        else begin
            result_reg <= gf_mul_ghash(in_a, in_b);
            valid_reg  <= start_i;
        end
    end

    assign out_o   = result_reg;
    assign valid_o = valid_reg;

endmodule
