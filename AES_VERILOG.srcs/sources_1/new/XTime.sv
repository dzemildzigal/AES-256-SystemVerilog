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
    output [0:7] output_byte
    );

    //always @* begin
    assign output_byte = x_time(input_byte);
    //end
function [0:7] x_time;
input [0:7] data;
begin
    case(data)
        8'h00: x_time=8'h00;
        8'h01: x_time=8'h02;
        8'h02: x_time=8'h04;
        8'h03: x_time=8'h06;
        8'h04: x_time=8'h08;
        8'h05: x_time=8'h0a;
        8'h06: x_time=8'h0c;
        8'h07: x_time=8'h0e;
        8'h08: x_time=8'h10;
        8'h09: x_time=8'h12;
        8'h0a: x_time=8'h14;
        8'h0b: x_time=8'h16;
        8'h0c: x_time=8'h18;
        8'h0d: x_time=8'h1a;
        8'h0e: x_time=8'h1c;
        8'h0f: x_time=8'h1e;
        8'h10: x_time=8'h20;
        8'h11: x_time=8'h22;
        8'h12: x_time=8'h24;
        8'h13: x_time=8'h26;
        8'h14: x_time=8'h28;
        8'h15: x_time=8'h2a;
        8'h16: x_time=8'h2c;
        8'h17: x_time=8'h2e;
        8'h18: x_time=8'h30;
        8'h19: x_time=8'h32;
        8'h1a: x_time=8'h34;
        8'h1b: x_time=8'h36;
        8'h1c: x_time=8'h38;
        8'h1d: x_time=8'h3a;
        8'h1e: x_time=8'h3c;
        8'h1f: x_time=8'h3e;
        8'h20: x_time=8'h40;
        8'h21: x_time=8'h42;
        8'h22: x_time=8'h44;
        8'h23: x_time=8'h46;
        8'h24: x_time=8'h48;
        8'h25: x_time=8'h4a;
        8'h26: x_time=8'h4c;
        8'h27: x_time=8'h4e;
        8'h28: x_time=8'h50;
        8'h29: x_time=8'h52;
        8'h2a: x_time=8'h54;
        8'h2b: x_time=8'h56;
        8'h2c: x_time=8'h58;
        8'h2d: x_time=8'h5a;
        8'h2e: x_time=8'h5c;
        8'h2f: x_time=8'h5e;
        8'h30: x_time=8'h60;
        8'h31: x_time=8'h62;
        8'h32: x_time=8'h64;
        8'h33: x_time=8'h66;
        8'h34: x_time=8'h68;
        8'h35: x_time=8'h6a;
        8'h36: x_time=8'h6c;
        8'h37: x_time=8'h6e;
        8'h38: x_time=8'h70;
        8'h39: x_time=8'h72;
        8'h3a: x_time=8'h74;
        8'h3b: x_time=8'h76;
        8'h3c: x_time=8'h78;
        8'h3d: x_time=8'h7a;
        8'h3e: x_time=8'h7c;
        8'h3f: x_time=8'h7e;
        8'h40: x_time=8'h80;
        8'h41: x_time=8'h82;
        8'h42: x_time=8'h84;
        8'h43: x_time=8'h86;
        8'h44: x_time=8'h88;
        8'h45: x_time=8'h8a;
        8'h46: x_time=8'h8c;
        8'h47: x_time=8'h8e;
        8'h48: x_time=8'h90;
        8'h49: x_time=8'h92;
        8'h4a: x_time=8'h94;
        8'h4b: x_time=8'h96;
        8'h4c: x_time=8'h98;
        8'h4d: x_time=8'h9a;
        8'h4e: x_time=8'h9c;
        8'h4f: x_time=8'h9e;
        8'h50: x_time=8'ha0;
        8'h51: x_time=8'ha2;
        8'h52: x_time=8'ha4;
        8'h53: x_time=8'ha6;
        8'h54: x_time=8'ha8;
        8'h55: x_time=8'haa;
        8'h56: x_time=8'hac;
        8'h57: x_time=8'hae;
        8'h58: x_time=8'hb0;
        8'h59: x_time=8'hb2;
        8'h5a: x_time=8'hb4;
        8'h5b: x_time=8'hb6;
        8'h5c: x_time=8'hb8;
        8'h5d: x_time=8'hba;
        8'h5e: x_time=8'hbc;
        8'h5f: x_time=8'hbe;
        8'h60: x_time=8'hc0;
        8'h61: x_time=8'hc2;
        8'h62: x_time=8'hc4;
        8'h63: x_time=8'hc6;
        8'h64: x_time=8'hc8;
        8'h65: x_time=8'hca;
        8'h66: x_time=8'hcc;
        8'h67: x_time=8'hce;
        8'h68: x_time=8'hd0;
        8'h69: x_time=8'hd2;
        8'h6a: x_time=8'hd4;
        8'h6b: x_time=8'hd6;
        8'h6c: x_time=8'hd8;
        8'h6d: x_time=8'hda;
        8'h6e: x_time=8'hdc;
        8'h6f: x_time=8'hde;
        8'h70: x_time=8'he0;
        8'h71: x_time=8'he2;
        8'h72: x_time=8'he4;
        8'h73: x_time=8'he6;
        8'h74: x_time=8'he8;
        8'h75: x_time=8'hea;
        8'h76: x_time=8'hec;
        8'h77: x_time=8'hee;
        8'h78: x_time=8'hf0;
        8'h79: x_time=8'hf2;
        8'h7a: x_time=8'hf4;
        8'h7b: x_time=8'hf6;
        8'h7c: x_time=8'hf8;
        8'h7d: x_time=8'hfa;
        8'h7e: x_time=8'hfc;
        8'h7f: x_time=8'hfe;
        8'h80: x_time=8'h1b;
        8'h81: x_time=8'h19;
        8'h82: x_time=8'h1f;
        8'h83: x_time=8'h1d;
        8'h84: x_time=8'h13;
        8'h85: x_time=8'h11;
        8'h86: x_time=8'h17;
        8'h87: x_time=8'h15;
        8'h88: x_time=8'h0b;
        8'h89: x_time=8'h09;
        8'h8a: x_time=8'h0f;
        8'h8b: x_time=8'h0d;
        8'h8c: x_time=8'h03;
        8'h8d: x_time=8'h01;
        8'h8e: x_time=8'h07;
        8'h8f: x_time=8'h05;
        8'h90: x_time=8'h3b;
        8'h91: x_time=8'h39;
        8'h92: x_time=8'h3f;
        8'h93: x_time=8'h3d;
        8'h94: x_time=8'h33;
        8'h95: x_time=8'h31;
        8'h96: x_time=8'h37;
        8'h97: x_time=8'h35;
        8'h98: x_time=8'h2b;
        8'h99: x_time=8'h29;
        8'h9a: x_time=8'h2f;
        8'h9b: x_time=8'h2d;
        8'h9c: x_time=8'h23;
        8'h9d: x_time=8'h21;
        8'h9e: x_time=8'h27;
        8'h9f: x_time=8'h25;
        8'ha0: x_time=8'h5b;
        8'ha1: x_time=8'h59;
        8'ha2: x_time=8'h5f;
        8'ha3: x_time=8'h5d;
        8'ha4: x_time=8'h53;
        8'ha5: x_time=8'h51;
        8'ha6: x_time=8'h57;
        8'ha7: x_time=8'h55;
        8'ha8: x_time=8'h4b;
        8'ha9: x_time=8'h49;
        8'haa: x_time=8'h4f;
        8'hab: x_time=8'h4d;
        8'hac: x_time=8'h43;
        8'had: x_time=8'h41;
        8'hae: x_time=8'h47;
        8'haf: x_time=8'h45;
        8'hb0: x_time=8'h7b;
        8'hb1: x_time=8'h79;
        8'hb2: x_time=8'h7f;
        8'hb3: x_time=8'h7d;
        8'hb4: x_time=8'h73;
        8'hb5: x_time=8'h71;
        8'hb6: x_time=8'h77;
        8'hb7: x_time=8'h75;
        8'hb8: x_time=8'h6b;
        8'hb9: x_time=8'h69;
        8'hba: x_time=8'h6f;
        8'hbb: x_time=8'h6d;
        8'hbc: x_time=8'h63;
        8'hbd: x_time=8'h61;
        8'hbe: x_time=8'h67;
        8'hbf: x_time=8'h65;
        8'hc0: x_time=8'h9b;
        8'hc1: x_time=8'h99;
        8'hc2: x_time=8'h9f;
        8'hc3: x_time=8'h9d;
        8'hc4: x_time=8'h93;
        8'hc5: x_time=8'h91;
        8'hc6: x_time=8'h97;
        8'hc7: x_time=8'h95;
        8'hc8: x_time=8'h8b;
        8'hc9: x_time=8'h89;
        8'hca: x_time=8'h8f;
        8'hcb: x_time=8'h8d;
        8'hcc: x_time=8'h83;
        8'hcd: x_time=8'h81;
        8'hce: x_time=8'h87;
        8'hcf: x_time=8'h85;
        8'hd0: x_time=8'hbb;
        8'hd1: x_time=8'hb9;
        8'hd2: x_time=8'hbf;
        8'hd3: x_time=8'hbd;
        8'hd4: x_time=8'hb3;
        8'hd5: x_time=8'hb1;
        8'hd6: x_time=8'hb7;
        8'hd7: x_time=8'hb5;
        8'hd8: x_time=8'hab;
        8'hd9: x_time=8'ha9;
        8'hda: x_time=8'haf;
        8'hdb: x_time=8'had;
        8'hdc: x_time=8'ha3;
        8'hdd: x_time=8'ha1;
        8'hde: x_time=8'ha7;
        8'hdf: x_time=8'ha5;
        8'he0: x_time=8'hdb;
        8'he1: x_time=8'hd9;
        8'he2: x_time=8'hdf;
        8'he3: x_time=8'hdd;
        8'he4: x_time=8'hd3;
        8'he5: x_time=8'hd1;
        8'he6: x_time=8'hd7;
        8'he7: x_time=8'hd5;
        8'he8: x_time=8'hcb;
        8'he9: x_time=8'hc9;
        8'hea: x_time=8'hcf;
        8'heb: x_time=8'hcd;
        8'hec: x_time=8'hc3;
        8'hed: x_time=8'hc1;
        8'hee: x_time=8'hc7;
        8'hef: x_time=8'hc5;
        8'hf0: x_time=8'hfb;
        8'hf1: x_time=8'hf9;
        8'hf2: x_time=8'hff;
        8'hf3: x_time=8'hfd;
        8'hf4: x_time=8'hf3;
        8'hf5: x_time=8'hf1;
        8'hf6: x_time=8'hf7;
        8'hf7: x_time=8'hf5;
        8'hf8: x_time=8'heb;
        8'hf9: x_time=8'he9;
        8'hfa: x_time=8'hef;
        8'hfb: x_time=8'hed;
        8'hfc: x_time=8'he3;
        8'hfd: x_time=8'he1;
        8'hfe: x_time=8'he7;
        8'hff: x_time=8'he5;
    endcase 
end
endfunction
    
endmodule
