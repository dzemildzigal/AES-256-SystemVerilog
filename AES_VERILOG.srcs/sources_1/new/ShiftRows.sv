`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: ShiftRows
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


module ShiftRows(
    input clk,
    input rst,
    input [0:127] input_state,
    output reg [0:127] output_state,
    output reg valid_data
    );
    
always @ (posedge clk) begin
    if (rst) begin
        output_state <= {128{1'b0}};
        valid_data <= 1'b0;
    end
    else if (!rst && !$isunknown(input_state)) begin
        
        //shift 0th row by 0, first row by 1, second by 2, third by 3
        //shift to the left
        /*
        temp = word[0]
        word[0] = word[1]
        word[1] = word[2]
        word[2] = word[3]
        word[3] = temp
        */
        
        output_state[0 +:8] = input_state[0 +:8]; 
        output_state[8 +:8] = input_state[40 +:8];
        output_state[16 +:8] = input_state[80 +:8];
        output_state[24 +:8] = input_state[120 +:8];
        
        output_state[32 +:8] = input_state[32 +:8];
        output_state[40 +:8] = input_state[72 +:8];
        output_state[48 +:8] = input_state[112 +:8];
        output_state[56 +:8] = input_state[24 +:8];
        
        output_state[64 +:8] = input_state[64 +:8];
        output_state[72 +:8] = input_state[104 +:8];
        output_state[80 +:8] = input_state[16 +:8];
        output_state[88 +:8] = input_state[56 +:8];
        
        output_state[96 +:8] = input_state[96 +:8];
        output_state[104 +:8] = input_state[8 +:8];
        output_state[112 +:8] = input_state[48 +:8];
        output_state[120 +:8] = input_state[88 +:8];
        
        
        valid_data <= 1'b1;
    end
    else begin
        valid_data <= 1'b0;
    end
end
    
endmodule
