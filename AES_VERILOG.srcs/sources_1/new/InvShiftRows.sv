`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module InvShiftRows(
    input  [0:127] input_state,
    output [0:127] output_state
    );

    assign output_state[0 +:8]   = input_state[0 +:8];
    assign output_state[8 +:8]   = input_state[104 +:8];
    assign output_state[16 +:8]  = input_state[80 +:8];
    assign output_state[24 +:8]  = input_state[56 +:8];

    assign output_state[32 +:8]  = input_state[32 +:8];
    assign output_state[40 +:8]  = input_state[8 +:8];
    assign output_state[48 +:8]  = input_state[112 +:8];
    assign output_state[56 +:8]  = input_state[88 +:8];

    assign output_state[64 +:8]  = input_state[64 +:8];
    assign output_state[72 +:8]  = input_state[40 +:8];
    assign output_state[80 +:8]  = input_state[16 +:8];
    assign output_state[88 +:8]  = input_state[120 +:8];

    assign output_state[96 +:8]  = input_state[96 +:8];
    assign output_state[104 +:8] = input_state[72 +:8];
    assign output_state[112 +:8] = input_state[48 +:8];
    assign output_state[120 +:8] = input_state[24 +:8];

endmodule

