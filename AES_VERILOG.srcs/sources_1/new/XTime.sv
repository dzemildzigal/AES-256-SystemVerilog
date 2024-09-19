`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: XTime
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


module XTime(
    //input clk,
    //input rst,
    input [0:7] input_byte,
    output reg [0:7] output_byte
    );
    reg [0:7] x_time [0:255];

    always @* begin
        $readmemh("x_time.mem", x_time);
        output_byte <= x_time[input_byte];
    end
endmodule
