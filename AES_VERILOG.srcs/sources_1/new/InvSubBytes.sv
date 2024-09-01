`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: InvSubBytes
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


module InvSubBytes(
    input clk,
    input rst,
    input [0:127] input_state,
    output reg [0:127] output_state,
    output reg valid_data
    );
integer i;
//initialize memory
reg [0:7] inv_s_box [0:255];
// Functionality
// All signals used in a procedural block should be declared as type reg  
always @ (posedge clk) begin 
    if (rst) begin
        output_state <= {128{1'b0}};
        valid_data <= 1'b0;
    end
    else begin
        for (i = 0; i < 16; i++) begin
            $readmemh("inv_s_box.mem", inv_s_box);
            output_state[i*8 +:8] <= inv_s_box[input_state[i*8 +:8]];
        end
        valid_data <= 1'b1; 
    end
end  
endmodule