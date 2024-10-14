`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: MixColumns
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module MixColumns(
    input [0:127] input_state,
    output reg [0:127] output_state
    );
reg [0:31] zeroth_result;
reg [0:31] first_result;
reg [0:31] second_result;
reg [0:31] third_result;

MixColumn mix_zeroth(
            .input_column(input_state[0:31]),
            .output_column(zeroth_result)
            );
MixColumn mix_first(
            .input_column(input_state[32:63]),
            .output_column(first_result)
            );
MixColumn mix_second(
            .input_column(input_state[64:95]),
            .output_column(second_result)
            );  
MixColumn mix_third(
            .input_column(input_state[96:127]),
            .output_column(third_result)
            );     
 
always @* begin    
output_state = {zeroth_result, first_result, second_result, third_result};
end   
endmodule
