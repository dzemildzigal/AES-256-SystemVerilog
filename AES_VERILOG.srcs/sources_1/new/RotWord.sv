`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: RotWord
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


module RotWord(
    input [0:31] word,
    output reg [0:31] out
    );
always @* begin
    out[0 +:8] = word[8 +:8];
    out[8 +:8] = word[16 +:8];
    out[16 +:8] = word[24 +:8];
    out[24 +:8] = word[0 +:8];
end
endmodule
