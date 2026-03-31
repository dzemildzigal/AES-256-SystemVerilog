`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module AddRoundKey(
    input [0:127] input_state,
    input [0:127] round_key,
    output[0:127] output_state
    );
    assign output_state = input_state ^ round_key;
endmodule
