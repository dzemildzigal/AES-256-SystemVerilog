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
    //input clk,
    //input rst,
    input [0:127] input_state,
    input [0:127] round_key,
    output[0:127] output_state
    //output reg valid_data
    );
// Additional variables
// integer i, j;
// Functionality
// All signals used in a procedural block should be declared as type reg  
//always @(*) begin
   assign output_state = input_state ^ round_key;
//end
/*always @ (posedge clk) begin 
    if (rst) begin
        output_state <= {128{1'b0}};
        valid_data <= 1'b0;
    end
    else if(!rst && !(^input_state === 1'bx) && !(^round_key === 1'bx)) begin
        output_state <= input_state ^ round_key;
        valid_data <= 1'b1; 
    end
    else begin
        valid_data <= 1'b0;
    end
end
*/
endmodule
