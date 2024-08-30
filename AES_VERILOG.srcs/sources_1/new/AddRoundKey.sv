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
    input clk,
    input rst,
    input [0:127] state,
    input [0:127] round_key,
    output reg [0:127] output_state,
    output reg valid_data
    );
// Additional variables
// integer i, j;
// Functionality
// All signals used in a procedural block should be declared as type reg  
always @ (posedge clk) begin 
    if (rst) begin
        output_state <= {128{1'b0}};
        valid_data <= 1'b0;
    end
    else begin
        output_state <= state ^ round_key;
        valid_data <= 1'b1; 
    end
end

endmodule
