`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: SubWord
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


module SubWord(
    input [0:31] word,
    output reg [0:31] out
    );
reg [0:7] s_box [0:255];
always @* begin
    $readmemh("s_box.mem", s_box);
    out[0 +:8] = s_box[word[0 +:8]];
    out[8 +:8] = s_box[word[8 +:8]];
    out[16 +:8] = s_box[word[16 +:8]];
    out[24 +:8] = s_box[word[24 +:8]];
end    
endmodule
