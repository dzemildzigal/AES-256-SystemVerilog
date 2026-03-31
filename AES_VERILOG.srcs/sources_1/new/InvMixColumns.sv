`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module InvMixColumns(
    input  [0:127] input_state,
    output [0:127] output_state
    );

wire [0:31] zeroth_result;
wire [0:31] first_result;
wire [0:31] second_result;
wire [0:31] third_result;

InvMixColumn inv_mix_zeroth(
    .input_column(input_state[0:31]),
    .output_column(zeroth_result)
);
InvMixColumn inv_mix_first(
    .input_column(input_state[32:63]),
    .output_column(first_result)
);
InvMixColumn inv_mix_second(
    .input_column(input_state[64:95]),
    .output_column(second_result)
);
InvMixColumn inv_mix_third(
    .input_column(input_state[96:127]),
    .output_column(third_result)
);

assign output_state = {zeroth_result, first_result, second_result, third_result};
endmodule
