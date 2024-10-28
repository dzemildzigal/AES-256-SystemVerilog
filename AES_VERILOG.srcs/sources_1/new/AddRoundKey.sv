`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Džemil Džigal
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: AddRoundKey
// Project Name: AES-256 in SystemVerilog
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


module AddRoundKey(
    input [0:127] input_state,
    input [0:127] round_key,
    output[0:127] output_state
    );
   assign output_state = input_state ^ round_key;
endmodule
