`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2024 02:25:20 AM
// Design Name: 
// Module Name: SubBytes
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


module SubBytes(
    input [0:127] input_state,
    output reg [0:127] output_state
    );

/*integer i;
//initialize memory
reg [0:7] s_box [0:255];
// Functionality
// All signals used in a procedural block should be declared as type reg  
always @ (posedge clk) begin 
    if (rst) begin
        output_state <= {128{1'b0}};
        valid_data <= 1'b0; 
    end
    else if(!rst && !(^input_state === 1'bx)) begin
        for (i = 0; i < 16; i++) begin
            $readmemh("s_box.mem", s_box);
            output_state[i*8 +:8] <= s_box[input_state[i*8 +:8]];
        end
        valid_data <= 1'b1;
    end
    else begin
        valid_data <= 1'b0;
    end
end  */

assign output_state = sbox(input_state);

function [0:127] sbox;
input [0:127] data;
begin
    integer i;
    for(i=0;i<16;i=i+1) begin
        case(data[i*8 +:8])
            8'h00: sbox[i*8 +:8]=8'h63;
            8'h01: sbox[i*8 +:8]=8'h7c;
            8'h02: sbox[i*8 +:8]=8'h77;
            8'h03: sbox[i*8 +:8]=8'h7b;
            8'h04: sbox[i*8 +:8]=8'hf2;
            8'h05: sbox[i*8 +:8]=8'h6b;
            8'h06: sbox[i*8 +:8]=8'h6f;
            8'h07: sbox[i*8 +:8]=8'hc5;
            8'h08: sbox[i*8 +:8]=8'h30;
            8'h09: sbox[i*8 +:8]=8'h01;
            8'h0a: sbox[i*8 +:8]=8'h67;
            8'h0b: sbox[i*8 +:8]=8'h2b;
            8'h0c: sbox[i*8 +:8]=8'hfe;
            8'h0d: sbox[i*8 +:8]=8'hd7;
            8'h0e: sbox[i*8 +:8]=8'hab;
            8'h0f: sbox[i*8 +:8]=8'h76;
            8'h10: sbox[i*8 +:8]=8'hca;
            8'h11: sbox[i*8 +:8]=8'h82;
            8'h12: sbox[i*8 +:8]=8'hc9;
            8'h13: sbox[i*8 +:8]=8'h7d;
            8'h14: sbox[i*8 +:8]=8'hfa;
            8'h15: sbox[i*8 +:8]=8'h59;
            8'h16: sbox[i*8 +:8]=8'h47;
            8'h17: sbox[i*8 +:8]=8'hf0;
            8'h18: sbox[i*8 +:8]=8'had;
            8'h19: sbox[i*8 +:8]=8'hd4;
            8'h1a: sbox[i*8 +:8]=8'ha2;
            8'h1b: sbox[i*8 +:8]=8'haf;
            8'h1c: sbox[i*8 +:8]=8'h9c;
            8'h1d: sbox[i*8 +:8]=8'ha4;
            8'h1e: sbox[i*8 +:8]=8'h72;
            8'h1f: sbox[i*8 +:8]=8'hc0;
            8'h20: sbox[i*8 +:8]=8'hb7;
            8'h21: sbox[i*8 +:8]=8'hfd;
            8'h22: sbox[i*8 +:8]=8'h93;
            8'h23: sbox[i*8 +:8]=8'h26;
            8'h24: sbox[i*8 +:8]=8'h36;
            8'h25: sbox[i*8 +:8]=8'h3f;
            8'h26: sbox[i*8 +:8]=8'hf7;
            8'h27: sbox[i*8 +:8]=8'hcc;
            8'h28: sbox[i*8 +:8]=8'h34;
            8'h29: sbox[i*8 +:8]=8'ha5;
            8'h2a: sbox[i*8 +:8]=8'he5;
            8'h2b: sbox[i*8 +:8]=8'hf1;
            8'h2c: sbox[i*8 +:8]=8'h71;
            8'h2d: sbox[i*8 +:8]=8'hd8;
            8'h2e: sbox[i*8 +:8]=8'h31;
            8'h2f: sbox[i*8 +:8]=8'h15;
            8'h30: sbox[i*8 +:8]=8'h04;
            8'h31: sbox[i*8 +:8]=8'hc7;
            8'h32: sbox[i*8 +:8]=8'h23;
            8'h33: sbox[i*8 +:8]=8'hc3;
            8'h34: sbox[i*8 +:8]=8'h18;
            8'h35: sbox[i*8 +:8]=8'h96;
            8'h36: sbox[i*8 +:8]=8'h05;
            8'h37: sbox[i*8 +:8]=8'h9a;
            8'h38: sbox[i*8 +:8]=8'h07;
            8'h39: sbox[i*8 +:8]=8'h12;
            8'h3a: sbox[i*8 +:8]=8'h80;
            8'h3b: sbox[i*8 +:8]=8'he2;
            8'h3c: sbox[i*8 +:8]=8'heb;
            8'h3d: sbox[i*8 +:8]=8'h27;
            8'h3e: sbox[i*8 +:8]=8'hb2;
            8'h3f: sbox[i*8 +:8]=8'h75;
            8'h40: sbox[i*8 +:8]=8'h09;
            8'h41: sbox[i*8 +:8]=8'h83;
            8'h42: sbox[i*8 +:8]=8'h2c;
            8'h43: sbox[i*8 +:8]=8'h1a;
            8'h44: sbox[i*8 +:8]=8'h1b;
            8'h45: sbox[i*8 +:8]=8'h6e;
            8'h46: sbox[i*8 +:8]=8'h5a;
            8'h47: sbox[i*8 +:8]=8'ha0;
            8'h48: sbox[i*8 +:8]=8'h52;
            8'h49: sbox[i*8 +:8]=8'h3b;
            8'h4a: sbox[i*8 +:8]=8'hd6;
            8'h4b: sbox[i*8 +:8]=8'hb3;
            8'h4c: sbox[i*8 +:8]=8'h29;
            8'h4d: sbox[i*8 +:8]=8'he3;
            8'h4e: sbox[i*8 +:8]=8'h2f;
            8'h4f: sbox[i*8 +:8]=8'h84;
            8'h50: sbox[i*8 +:8]=8'h53;
            8'h51: sbox[i*8 +:8]=8'hd1;
            8'h52: sbox[i*8 +:8]=8'h00;
            8'h53: sbox[i*8 +:8]=8'hed;
            8'h54: sbox[i*8 +:8]=8'h20;
            8'h55: sbox[i*8 +:8]=8'hfc;
            8'h56: sbox[i*8 +:8]=8'hb1;
            8'h57: sbox[i*8 +:8]=8'h5b;
            8'h58: sbox[i*8 +:8]=8'h6a;
            8'h59: sbox[i*8 +:8]=8'hcb;
            8'h5a: sbox[i*8 +:8]=8'hbe;
            8'h5b: sbox[i*8 +:8]=8'h39;
            8'h5c: sbox[i*8 +:8]=8'h4a;
            8'h5d: sbox[i*8 +:8]=8'h4c;
            8'h5e: sbox[i*8 +:8]=8'h58;
            8'h5f: sbox[i*8 +:8]=8'hcf;
            8'h60: sbox[i*8 +:8]=8'hd0;
            8'h61: sbox[i*8 +:8]=8'hef;
            8'h62: sbox[i*8 +:8]=8'haa;
            8'h63: sbox[i*8 +:8]=8'hfb;
            8'h64: sbox[i*8 +:8]=8'h43;
            8'h65: sbox[i*8 +:8]=8'h4d;
            8'h66: sbox[i*8 +:8]=8'h33;
            8'h67: sbox[i*8 +:8]=8'h85;
            8'h68: sbox[i*8 +:8]=8'h45;
            8'h69: sbox[i*8 +:8]=8'hf9;
            8'h6a: sbox[i*8 +:8]=8'h02;
            8'h6b: sbox[i*8 +:8]=8'h7f;
            8'h6c: sbox[i*8 +:8]=8'h50;
            8'h6d: sbox[i*8 +:8]=8'h3c;
            8'h6e: sbox[i*8 +:8]=8'h9f;
            8'h6f: sbox[i*8 +:8]=8'ha8;
            8'h70: sbox[i*8 +:8]=8'h51;
            8'h71: sbox[i*8 +:8]=8'ha3;
            8'h72: sbox[i*8 +:8]=8'h40;
            8'h73: sbox[i*8 +:8]=8'h8f;
            8'h74: sbox[i*8 +:8]=8'h92;
            8'h75: sbox[i*8 +:8]=8'h9d;
            8'h76: sbox[i*8 +:8]=8'h38;
            8'h77: sbox[i*8 +:8]=8'hf5;
            8'h78: sbox[i*8 +:8]=8'hbc;
            8'h79: sbox[i*8 +:8]=8'hb6;
            8'h7a: sbox[i*8 +:8]=8'hda;
            8'h7b: sbox[i*8 +:8]=8'h21;
            8'h7c: sbox[i*8 +:8]=8'h10;
            8'h7d: sbox[i*8 +:8]=8'hff;
            8'h7e: sbox[i*8 +:8]=8'hf3;
            8'h7f: sbox[i*8 +:8]=8'hd2;
            8'h80: sbox[i*8 +:8]=8'hcd;
            8'h81: sbox[i*8 +:8]=8'h0c;
            8'h82: sbox[i*8 +:8]=8'h13;
            8'h83: sbox[i*8 +:8]=8'hec;
            8'h84: sbox[i*8 +:8]=8'h5f;
            8'h85: sbox[i*8 +:8]=8'h97;
            8'h86: sbox[i*8 +:8]=8'h44;
            8'h87: sbox[i*8 +:8]=8'h17;
            8'h88: sbox[i*8 +:8]=8'hc4;
            8'h89: sbox[i*8 +:8]=8'ha7;
            8'h8a: sbox[i*8 +:8]=8'h7e;
            8'h8b: sbox[i*8 +:8]=8'h3d;
            8'h8c: sbox[i*8 +:8]=8'h64;
            8'h8d: sbox[i*8 +:8]=8'h5d;
            8'h8e: sbox[i*8 +:8]=8'h19;
            8'h8f: sbox[i*8 +:8]=8'h73;
            8'h90: sbox[i*8 +:8]=8'h60;
            8'h91: sbox[i*8 +:8]=8'h81;
            8'h92: sbox[i*8 +:8]=8'h4f;
            8'h93: sbox[i*8 +:8]=8'hdc;
            8'h94: sbox[i*8 +:8]=8'h22;
            8'h95: sbox[i*8 +:8]=8'h2a;
            8'h96: sbox[i*8 +:8]=8'h90;
            8'h97: sbox[i*8 +:8]=8'h88;
            8'h98: sbox[i*8 +:8]=8'h46;
            8'h99: sbox[i*8 +:8]=8'hee;
            8'h9a: sbox[i*8 +:8]=8'hb8;
            8'h9b: sbox[i*8 +:8]=8'h14;
            8'h9c: sbox[i*8 +:8]=8'hde;
            8'h9d: sbox[i*8 +:8]=8'h5e;
            8'h9e: sbox[i*8 +:8]=8'h0b;
            8'h9f: sbox[i*8 +:8]=8'hdb;
            8'ha0: sbox[i*8 +:8]=8'he0;
            8'ha1: sbox[i*8 +:8]=8'h32;
            8'ha2: sbox[i*8 +:8]=8'h3a;
            8'ha3: sbox[i*8 +:8]=8'h0a;
            8'ha4: sbox[i*8 +:8]=8'h49;
            8'ha5: sbox[i*8 +:8]=8'h06;
            8'ha6: sbox[i*8 +:8]=8'h24;
            8'ha7: sbox[i*8 +:8]=8'h5c;
            8'ha8: sbox[i*8 +:8]=8'hc2;
            8'ha9: sbox[i*8 +:8]=8'hd3;
            8'haa: sbox[i*8 +:8]=8'hac;
            8'hab: sbox[i*8 +:8]=8'h62;
            8'hac: sbox[i*8 +:8]=8'h91;
            8'had: sbox[i*8 +:8]=8'h95;
            8'hae: sbox[i*8 +:8]=8'he4;
            8'haf: sbox[i*8 +:8]=8'h79;
            8'hb0: sbox[i*8 +:8]=8'he7;
            8'hb1: sbox[i*8 +:8]=8'hc8;
            8'hb2: sbox[i*8 +:8]=8'h37;
            8'hb3: sbox[i*8 +:8]=8'h6d;
            8'hb4: sbox[i*8 +:8]=8'h8d;
            8'hb5: sbox[i*8 +:8]=8'hd5;
            8'hb6: sbox[i*8 +:8]=8'h4e;
            8'hb7: sbox[i*8 +:8]=8'ha9;
            8'hb8: sbox[i*8 +:8]=8'h6c;
            8'hb9: sbox[i*8 +:8]=8'h56;
            8'hba: sbox[i*8 +:8]=8'hf4;
            8'hbb: sbox[i*8 +:8]=8'hea;
            8'hbc: sbox[i*8 +:8]=8'h65;
            8'hbd: sbox[i*8 +:8]=8'h7a;
            8'hbe: sbox[i*8 +:8]=8'hae;
            8'hbf: sbox[i*8 +:8]=8'h08;
            8'hc0: sbox[i*8 +:8]=8'hba;
            8'hc1: sbox[i*8 +:8]=8'h78;
            8'hc2: sbox[i*8 +:8]=8'h25;
            8'hc3: sbox[i*8 +:8]=8'h2e;
            8'hc4: sbox[i*8 +:8]=8'h1c;
            8'hc5: sbox[i*8 +:8]=8'ha6;
            8'hc6: sbox[i*8 +:8]=8'hb4;
            8'hc7: sbox[i*8 +:8]=8'hc6;
            8'hc8: sbox[i*8 +:8]=8'he8;
            8'hc9: sbox[i*8 +:8]=8'hdd;
            8'hca: sbox[i*8 +:8]=8'h74;
            8'hcb: sbox[i*8 +:8]=8'h1f;
            8'hcc: sbox[i*8 +:8]=8'h4b;
            8'hcd: sbox[i*8 +:8]=8'hbd;
            8'hce: sbox[i*8 +:8]=8'h8b;
            8'hcf: sbox[i*8 +:8]=8'h8a;
            8'hd0: sbox[i*8 +:8]=8'h70;
            8'hd1: sbox[i*8 +:8]=8'h3e;
            8'hd2: sbox[i*8 +:8]=8'hb5;
            8'hd3: sbox[i*8 +:8]=8'h66;
            8'hd4: sbox[i*8 +:8]=8'h48;
            8'hd5: sbox[i*8 +:8]=8'h03;
            8'hd6: sbox[i*8 +:8]=8'hf6;
            8'hd7: sbox[i*8 +:8]=8'h0e;
            8'hd8: sbox[i*8 +:8]=8'h61;
            8'hd9: sbox[i*8 +:8]=8'h35;
            8'hda: sbox[i*8 +:8]=8'h57;
            8'hdb: sbox[i*8 +:8]=8'hb9;
            8'hdc: sbox[i*8 +:8]=8'h86;
            8'hdd: sbox[i*8 +:8]=8'hc1;
            8'hde: sbox[i*8 +:8]=8'h1d;
            8'hdf: sbox[i*8 +:8]=8'h9e;
            8'he0: sbox[i*8 +:8]=8'he1;
            8'he1: sbox[i*8 +:8]=8'hf8;
            8'he2: sbox[i*8 +:8]=8'h98;
            8'he3: sbox[i*8 +:8]=8'h11;
            8'he4: sbox[i*8 +:8]=8'h69;
            8'he5: sbox[i*8 +:8]=8'hd9;
            8'he6: sbox[i*8 +:8]=8'h8e;
            8'he7: sbox[i*8 +:8]=8'h94;
            8'he8: sbox[i*8 +:8]=8'h9b;
            8'he9: sbox[i*8 +:8]=8'h1e;
            8'hea: sbox[i*8 +:8]=8'h87;
            8'heb: sbox[i*8 +:8]=8'he9;
            8'hec: sbox[i*8 +:8]=8'hce;
            8'hed: sbox[i*8 +:8]=8'h55;
            8'hee: sbox[i*8 +:8]=8'h28;
            8'hef: sbox[i*8 +:8]=8'hdf;
            8'hf0: sbox[i*8 +:8]=8'h8c;
            8'hf1: sbox[i*8 +:8]=8'ha1;
            8'hf2: sbox[i*8 +:8]=8'h89;
            8'hf3: sbox[i*8 +:8]=8'h0d;
            8'hf4: sbox[i*8 +:8]=8'hbf;
            8'hf5: sbox[i*8 +:8]=8'he6;
            8'hf6: sbox[i*8 +:8]=8'h42;
            8'hf7: sbox[i*8 +:8]=8'h68;
            8'hf8: sbox[i*8 +:8]=8'h41;
            8'hf9: sbox[i*8 +:8]=8'h99;
            8'hfa: sbox[i*8 +:8]=8'h2d;
            8'hfb: sbox[i*8 +:8]=8'h0f;
            8'hfc: sbox[i*8 +:8]=8'hb0;
            8'hfd: sbox[i*8 +:8]=8'h54;
            8'hfe: sbox[i*8 +:8]=8'hbb;
            8'hff: sbox[i*8 +:8]=8'h16;
       endcase
   end
end
endfunction

endmodule