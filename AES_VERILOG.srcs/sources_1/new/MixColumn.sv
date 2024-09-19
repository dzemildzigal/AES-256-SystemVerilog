`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:29:16 AM
// Design Name: 
// Module Name: MixColumn
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


module MixColumn(
    input [0:31] input_column,
    output reg [0:31] output_column
    );
    wire [0:7] zeroth_output;
    wire [0:7] first_output;
    wire [0:7] second_output;
    wire [0:7] third_output;
    reg [0:7] u;
    reg [0:7] t;
    XTime zeroth(.input_byte(input_column[0 +:8] ^ input_column[8 +:8]),
                    .output_byte(zeroth_output)
                    );
    XTime first(.input_byte(input_column[8 +:8] ^ input_column[16 +:8]),
                .output_byte(first_output)
                );
    XTime second(.input_byte(input_column[16 +:8] ^ input_column[24 +:8]),
                .output_byte(second_output)
                );
    XTime third(.input_byte(input_column[24 +:8] ^ u),
                .output_byte(third_output)
                );
    always @ * begin
    
        t = input_column[0 +:8] ^ input_column[8 +:8] ^ input_column[16 +:8] ^ input_column[24 +:8];
        u = input_column[0 +:8];
        
        output_column = {input_column[0 +:8] ^ t ^zeroth_output, 
                         input_column[8 +:8] ^ t ^ first_output, 
                         input_column[16 +:8] ^ t ^ second_output, 
                         input_column[24 +:8] ^ t ^ third_output};
    end
endmodule
