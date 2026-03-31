`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Inverse MixColumn: multiply one 4-byte column by the inverse matrix
//   [14 11 13  9]
//   [ 9 14 11 13]
//   [13  9 14 11]
//   [11 13  9 14]
// in GF(2^8) with irreducible polynomial x^8 + x^4 + x^3 + x + 1.
//
// Multiply-by-N via XTime chains:
//   x2 = XTime(a)
//   x4 = XTime(x2)
//   x8 = XTime(x4)
//   x9  = x8 ^ a       (8+1)
//   x11 = x8 ^ x2 ^ a  (8+2+1)
//   x13 = x8 ^ x4 ^ a  (8+4+1)
//   x14 = x8 ^ x4 ^ x2 (8+4+2)

module InvMixColumn(
    input  [0:31] input_column,
    output [0:31] output_column
    );

    wire [0:7] b0 = input_column[0  +:8];
    wire [0:7] b1 = input_column[8  +:8];
    wire [0:7] b2 = input_column[16 +:8];
    wire [0:7] b3 = input_column[24 +:8];

    // XTime chains for each byte: x2, x4, x8
    wire [0:7] b0_x2, b0_x4, b0_x8;
    wire [0:7] b1_x2, b1_x4, b1_x8;
    wire [0:7] b2_x2, b2_x4, b2_x8;
    wire [0:7] b3_x2, b3_x4, b3_x8;

    XTime xt_b0_2(.input_byte(b0),    .output_byte(b0_x2));
    XTime xt_b0_4(.input_byte(b0_x2), .output_byte(b0_x4));
    XTime xt_b0_8(.input_byte(b0_x4), .output_byte(b0_x8));

    XTime xt_b1_2(.input_byte(b1),    .output_byte(b1_x2));
    XTime xt_b1_4(.input_byte(b1_x2), .output_byte(b1_x4));
    XTime xt_b1_8(.input_byte(b1_x4), .output_byte(b1_x8));

    XTime xt_b2_2(.input_byte(b2),    .output_byte(b2_x2));
    XTime xt_b2_4(.input_byte(b2_x2), .output_byte(b2_x4));
    XTime xt_b2_8(.input_byte(b2_x4), .output_byte(b2_x8));

    XTime xt_b3_2(.input_byte(b3),    .output_byte(b3_x2));
    XTime xt_b3_4(.input_byte(b3_x2), .output_byte(b3_x4));
    XTime xt_b3_8(.input_byte(b3_x4), .output_byte(b3_x8));

    // Derived multiplications
    wire [0:7] b0_x9  = b0_x8 ^ b0;
    wire [0:7] b0_x11 = b0_x8 ^ b0_x2 ^ b0;
    wire [0:7] b0_x13 = b0_x8 ^ b0_x4 ^ b0;
    wire [0:7] b0_x14 = b0_x8 ^ b0_x4 ^ b0_x2;

    wire [0:7] b1_x9  = b1_x8 ^ b1;
    wire [0:7] b1_x11 = b1_x8 ^ b1_x2 ^ b1;
    wire [0:7] b1_x13 = b1_x8 ^ b1_x4 ^ b1;
    wire [0:7] b1_x14 = b1_x8 ^ b1_x4 ^ b1_x2;

    wire [0:7] b2_x9  = b2_x8 ^ b2;
    wire [0:7] b2_x11 = b2_x8 ^ b2_x2 ^ b2;
    wire [0:7] b2_x13 = b2_x8 ^ b2_x4 ^ b2;
    wire [0:7] b2_x14 = b2_x8 ^ b2_x4 ^ b2_x2;

    wire [0:7] b3_x9  = b3_x8 ^ b3;
    wire [0:7] b3_x11 = b3_x8 ^ b3_x2 ^ b3;
    wire [0:7] b3_x13 = b3_x8 ^ b3_x4 ^ b3;
    wire [0:7] b3_x14 = b3_x8 ^ b3_x4 ^ b3_x2;

    // out[0] = 14*b0 ^ 11*b1 ^ 13*b2 ^  9*b3
    // out[1] =  9*b0 ^ 14*b1 ^ 11*b2 ^ 13*b3
    // out[2] = 13*b0 ^  9*b1 ^ 14*b2 ^ 11*b3
    // out[3] = 11*b0 ^ 13*b1 ^  9*b2 ^ 14*b3
    assign output_column = {
        b0_x14 ^ b1_x11 ^ b2_x13 ^ b3_x9,
        b0_x9  ^ b1_x14 ^ b2_x11 ^ b3_x13,
        b0_x13 ^ b1_x9  ^ b2_x14 ^ b3_x11,
        b0_x11 ^ b1_x13 ^ b2_x9  ^ b3_x14
    };
endmodule
